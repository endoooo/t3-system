defmodule T3System.Cloudinary do
  @moduledoc """
  Minimal client for Cloudinary's signed upload API.

  Configured via `config :t3_system, T3System.Cloudinary`, which reads the
  `CLOUDINARY_URL` env var (`cloudinary://<api_key>:<api_secret>@<cloud_name>`)
  in `config/runtime.exs`. The optional `CLOUDINARY_FOLDER` env var sets a root
  folder (e.g. `t3_system_dev`) that all uploads are nested under.
  """

  # Caps stored images at 800x800 without cropping, keeping uploads small.
  @incoming_transformation "c_limit,w_800,h_800"

  @doc """
  Uploads the image at `path` into `folder`, nested under the configured root
  folder (e.g. `"players"` becomes `"t3_system/players"`).

  Returns the image's `secure_url` on success.
  """
  @spec upload_image(Path.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def upload_image(path, folder) do
    with {:ok, config} <- fetch_config() do
      params = %{
        "folder" =>
          Enum.join(Enum.reject([config[:root_folder], folder], &(&1 in [nil, ""])), "/"),
        "timestamp" => System.os_time(:second),
        "transformation" => @incoming_transformation
      }

      fields =
        params
        |> Map.merge(%{
          "api_key" => config[:api_key],
          "signature" => sign(params, config[:api_secret])
        })
        |> Enum.map(fn {key, value} -> {key, to_string(value)} end)
        |> Kernel.++([{"file", File.stream!(path, 2048)}])

      case post(config, "upload", form_multipart: fields) do
        {:ok, %{"secure_url" => url}} -> {:ok, url}
        {:ok, body} -> {:error, error_message(body)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Deletes the image behind a URL previously returned by `upload_image/2`.

  URLs that don't belong to the configured Cloudinary account (or `nil`) are
  ignored and return `:ok`, so callers can pass any stored picture URL.
  """
  @spec delete_image(String.t() | nil) :: :ok | {:error, term()}
  def delete_image(url) do
    with {:ok, config} <- fetch_config(),
         {:ok, public_id} <- public_id(url, config[:cloud_name]) do
      params = %{"public_id" => public_id, "timestamp" => System.os_time(:second)}

      fields =
        Map.merge(params, %{
          "api_key" => config[:api_key],
          "signature" => sign(params, config[:api_secret])
        })

      # "not found" means the image is already gone, which is what we wanted.
      case post(config, "destroy", form: fields) do
        {:ok, %{"result" => result}} when result in ["ok", "not found"] -> :ok
        {:ok, body} -> {:error, error_message(body)}
        {:error, reason} -> {:error, reason}
      end
    else
      :ignore -> :ok
      error -> error
    end
  end

  @doc """
  Returns a square, face-centered thumbnail URL of `size` pixels for a
  Cloudinary image URL. Other URLs are returned unchanged.
  """
  @spec thumbnail_url(String.t() | nil, pos_integer()) :: String.t() | nil
  def thumbnail_url(url, size) when is_binary(url) do
    if String.starts_with?(url, "https://res.cloudinary.com/") do
      String.replace(
        url,
        "/image/upload/",
        "/image/upload/c_fill,g_face,w_#{size},h_#{size},f_auto,q_auto/",
        global: false
      )
    else
      url
    end
  end

  def thumbnail_url(url, _size), do: url

  defp post(config, action, options) do
    [url: "https://api.cloudinary.com/v1_1/#{config[:cloud_name]}/image/#{action}"]
    |> Keyword.merge(options)
    |> Keyword.merge(config[:req_options] || [])
    |> Req.post()
    |> case do
      {:ok, %Req.Response{body: body}} -> {:ok, body}
      {:error, exception} -> {:error, Exception.message(exception)}
    end
  end

  # https://res.cloudinary.com/<cloud>/image/upload/v123/players/abc.png -> "players/abc"
  defp public_id(url, cloud_name) when is_binary(url) do
    prefix = "https://res.cloudinary.com/#{cloud_name}/image/upload/"

    with true <- String.starts_with?(url, prefix),
         [_, public_id] <-
           Regex.run(~r{^(?:v\d+/)?(.+)\.\w+$}, String.replace_prefix(url, prefix, "")) do
      {:ok, public_id}
    else
      _ -> :ignore
    end
  end

  defp public_id(_url, _cloud_name), do: :ignore

  # https://cloudinary.com/documentation/authentication_signatures
  defp sign(params, api_secret) do
    to_sign =
      params
      |> Enum.sort()
      |> Enum.map_join("&", fn {key, value} -> "#{key}=#{value}" end)

    :crypto.hash(:sha, to_sign <> api_secret) |> Base.encode16(case: :lower)
  end

  defp fetch_config do
    config = Application.get_env(:t3_system, __MODULE__, [])

    if Enum.all?([:cloud_name, :api_key, :api_secret], &config[&1]) do
      {:ok, config}
    else
      {:error, "Cloudinary is not configured (missing CLOUDINARY_URL)"}
    end
  end

  defp error_message(%{"error" => %{"message" => message}}), do: message
  defp error_message(body), do: inspect(body)
end
