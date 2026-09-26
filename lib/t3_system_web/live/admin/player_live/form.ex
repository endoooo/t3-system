defmodule T3SystemWeb.Admin.PlayerLive.Form do
  use T3SystemWeb, :live_view

  alias T3System.Cloudinary
  alias T3System.Players
  alias T3System.Players.Player

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="players">
      <.header>
        {@page_title}
        <:subtitle>{gettext("Use this form to manage player records in your database.")}</:subtitle>
      </.header>

      <.form
        for={@form}
        id="player-form"
        phx-change="validate"
        phx-submit="save"
        class="max-w-xl space-y-6"
      >
        <div class="space-y-5">
          <.input field={@form[:name]} type="text" label={gettext("Nome")} />
          <.input field={@form[:birthdate]} type="date" label={gettext("Birthdate")} />
          <div>
            <.label for={@uploads.picture.ref}>{gettext("Picture")}</.label>
            <div class="flex items-center gap-4" phx-drop-target={@uploads.picture.ref}>
              <%= case @uploads.picture.entries do %>
                <% [entry | _] -> %>
                  <.live_img_preview
                    entry={entry}
                    class="size-20 shrink-0 rounded-full object-cover"
                  />
                <% [] -> %>
                  <.avatar
                    src={current_picture_url(@player, @remove_picture)}
                    name={@player.name}
                    size="lg"
                  />
              <% end %>
              <div class="flex flex-col items-start gap-2">
                <.live_file_input
                  upload={@uploads.picture}
                  class="text-sm text-fg-muted file:mr-3 file:cursor-pointer file:rounded-md file:border-0 file:bg-surface-raised file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-fg hover:file:bg-surface"
                />
                <.button
                  :if={
                    @uploads.picture.entries != [] or current_picture_url(@player, @remove_picture)
                  }
                  type="button"
                  variant="ghost"
                  size="sm"
                  phx-click="remove_picture"
                  phx-value-ref={Enum.map_join(@uploads.picture.entries, & &1.ref)}
                >
                  <.icon name="hero-trash" class="size-4" /> {gettext("Remove picture")}
                </.button>
              </div>
            </div>
            <p
              :for={err <- upload_errors(@uploads.picture) ++ entry_errors(@uploads.picture)}
              class="mt-1.5 flex items-center gap-1.5 text-sm text-danger"
            >
              <.icon name="hero-exclamation-circle-mini" class="size-4 shrink-0" />
              {upload_error_to_string(err)}
            </p>
          </div>
        </div>
        <.form_actions>
          <.button phx-disable-with={gettext("Saving...")} variant="primary">
            {gettext("Save Player")}
          </.button>
          <.button
            :if={@live_action == :new}
            phx-disable-with={gettext("Saving...")}
            name="save_action"
            value="add_more"
          >
            {gettext("Save and add more")}
          </.button>
          <.button navigate={return_path(@return_to, @player)}>{gettext("Cancelar")}</.button>
        </.form_actions>
      </.form>
    </Layouts.settings>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> allow_upload(:picture,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 5_000_000
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    player = Players.get_player!(id)

    socket
    |> assign(:page_title, gettext("Edit Player"))
    |> assign(:player, player)
    |> assign(:remove_picture, false)
    |> assign(:form, to_form(Players.change_player(player)))
  end

  defp apply_action(socket, :new, _params) do
    player = %Player{}

    socket
    |> assign(:page_title, gettext("New Player"))
    |> assign(:player, player)
    |> assign(:remove_picture, false)
    |> assign(:form, to_form(Players.change_player(player)))
  end

  @impl true
  def handle_event("validate", %{"player" => player_params}, socket) do
    changeset = Players.change_player(socket.assigns.player, player_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  # Selected (not yet uploaded) files are simply discarded. The stored picture
  # is only cleared on save, so "Cancelar" still leaves it untouched.
  def handle_event("remove_picture", %{"ref" => ref}, socket) when ref != "" do
    {:noreply, cancel_upload(socket, :picture, ref)}
  end

  def handle_event("remove_picture", _params, socket) do
    {:noreply, assign(socket, :remove_picture, true)}
  end

  def handle_event("save", %{"player" => player_params} = params, socket) do
    action =
      if params["save_action"] == "add_more",
        do: :new_and_add_more,
        else: socket.assigns.live_action

    case put_uploaded_picture(socket, player_params) do
      {:ok, player_params} ->
        save_player(socket, action, player_params)

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, gettext("Could not upload picture: %{reason}", reason: reason))}
    end
  end

  # Uploads only once the rest of the form is valid, to avoid orphaned images.
  # On failure the entry is postponed so the user can retry without reselecting.
  defp put_uploaded_picture(socket, player_params) do
    if Players.change_player(socket.assigns.player, player_params).valid? do
      socket
      |> consume_uploaded_entries(:picture, fn %{path: path}, _entry -> upload_picture(path) end)
      |> case do
        [] when socket.assigns.remove_picture -> {:ok, Map.put(player_params, "picture_url", nil)}
        [] -> {:ok, player_params}
        [{:ok, url}] -> {:ok, Map.put(player_params, "picture_url", url)}
        [{:error, reason}] -> {:error, reason}
      end
    else
      {:ok, player_params}
    end
  end

  defp upload_picture(path) do
    case Cloudinary.upload_image(path, "players") do
      {:ok, url} -> {:ok, {:ok, url}}
      {:error, reason} -> {:postpone, {:error, reason}}
    end
  end

  defp save_player(socket, :new_and_add_more, player_params) do
    case Players.create_player(socket.assigns.current_scope, player_params) do
      {:ok, _player} ->
        player = %Player{}

        {:noreply,
         socket
         |> put_flash(:info, gettext("Player created successfully"))
         |> assign(:player, player)
         |> assign(:remove_picture, false)
         |> assign(:form, to_form(Players.change_player(player)))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_player(socket, :edit, player_params) do
    case Players.update_player(socket.assigns.current_scope, socket.assigns.player, player_params) do
      {:ok, player} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Player updated successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to, player))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_player(socket, :new, player_params) do
    case Players.create_player(socket.assigns.current_scope, player_params) do
      {:ok, player} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Player created successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to, player))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp current_picture_url(_player, true = _removed), do: nil
  defp current_picture_url(player, false), do: player.picture_url

  defp entry_errors(upload), do: Enum.flat_map(upload.entries, &upload_errors(upload, &1))

  defp upload_error_to_string(:too_large), do: gettext("Picture must be at most 5MB")
  defp upload_error_to_string(:not_accepted), do: gettext("Picture must be a JPG, PNG or WebP")
  defp upload_error_to_string(:too_many_files), do: gettext("Only one picture is allowed")
  defp upload_error_to_string(_), do: gettext("Invalid picture")

  defp return_path("index", _player), do: ~p"/admin/players"
  defp return_path("show", player), do: ~p"/admin/players/#{player}"
end
