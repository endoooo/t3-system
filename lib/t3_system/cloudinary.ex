defmodule T3System.Cloudinary do
  @moduledoc """
  Minimal client for Cloudinary's signed upload API.

  Configured via `config :t3_system, T3System.Cloudinary`, which reads the
  `CLOUDINARY_URL` env var (`cloudinary://<api_key>:<api_secret>@<cloud_name>`)
  in `config/runtime.exs`.
  """

  # Caps stored images at 800x800 without cropping, keeping uploads small.
  @incoming_transformation "c_limit,w_800,h_800"

  @doc """
  Uploads the image at `path` into the given Cloudinary `folder`.

  Returns the image's `secure_url` on success.
  """
  @spec upload_image(Path.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def upload_image(path, folder) do
    with {:ok, config} <- fetch_config() do
      params = %{
        "folder" => folder,
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

      [
        url: "https://api.cloudinary.com/v1_1/#{config[:cloud_name]}/image/upload",
        form_multipart: fields
      ]
      |> Keyword.merge(config[:req_options] || [])
      |> Req.post()
      |> case do
        {:ok, %Req.Response{status: 200, body: %{"secure_url" => url}}} -> {:ok, url}
        {:ok, %Req.Response{body: body}} -> {:error, error_message(body)}
        {:error, exception} -> {:error, Exception.message(exception)}
      end
    end
  end

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
