defmodule T3SystemWeb.Admin.PlayerLive.Form do
  use T3SystemWeb, :live_view

  alias T3System.Players
  alias T3System.Players.Player

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>{gettext("Use this form to manage player records in your database.")}</:subtitle>
      </.header>

      <.form for={@form} id="player-form" phx-change="validate" phx-submit="save">
        <div class="space-y-4">
          <.input field={@form[:name]} type="text" label={gettext("Nome")} />
          <.input field={@form[:birthdate]} type="date" label={gettext("Birthdate")} />
          <.input field={@form[:picture_url]} type="text" label={gettext("Picture url")} />
        </div>
        <footer class="mt-6">
          <.button phx-disable-with={gettext("Saving...")} variant="primary">
            {gettext("Save Player")}
          </.button>
          <.button
            :if={@live_action == :new}
            phx-disable-with={gettext("Saving...")}
            phx-click="save_and_add_more"
            type="button"
          >
            {gettext("Save and add more")}
          </.button>
          <.button navigate={return_path(@return_to, @player)}>{gettext("Cancelar")}</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    player = Players.get_player!(id)

    socket
    |> assign(:page_title, gettext("Edit Player"))
    |> assign(:player, player)
    |> assign(:form, to_form(Players.change_player(player)))
  end

  defp apply_action(socket, :new, _params) do
    player = %Player{}

    socket
    |> assign(:page_title, gettext("New Player"))
    |> assign(:player, player)
    |> assign(:form, to_form(Players.change_player(player)))
  end

  @impl true
  def handle_event("validate", %{"player" => player_params}, socket) do
    changeset = Players.change_player(socket.assigns.player, player_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"player" => player_params}, socket) do
    save_player(socket, socket.assigns.live_action, player_params)
  end

  def handle_event("save_and_add_more", _params, socket) do
    player_params = socket.assigns.form.params || %{}

    case Players.create_player(socket.assigns.current_scope, player_params) do
      {:ok, _player} ->
        player = %Player{}

        {:noreply,
         socket
         |> put_flash(:info, gettext("Player created successfully"))
         |> assign(:player, player)
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

  defp return_path("index", _player), do: ~p"/admin/players"
  defp return_path("show", player), do: ~p"/admin/players/#{player}"
end
