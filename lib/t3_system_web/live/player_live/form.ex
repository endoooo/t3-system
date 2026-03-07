defmodule T3SystemWeb.PlayerLive.Form do
  use T3SystemWeb, :live_view

  alias T3System.Players
  alias T3System.Players.Player

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage player records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="player-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:birthdate]} type="date" label="Birthdate" />
        <.input field={@form[:picture_url]} type="text" label="Picture url" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Player</.button>
          <.button navigate={return_path(@return_to, @player)}>Cancel</.button>
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
    |> assign(:page_title, "Edit Player")
    |> assign(:player, player)
    |> assign(:form, to_form(Players.change_player(player)))
  end

  defp apply_action(socket, :new, _params) do
    player = %Player{}

    socket
    |> assign(:page_title, "New Player")
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

  defp save_player(socket, :edit, player_params) do
    case Players.update_player(socket.assigns.current_scope, socket.assigns.player, player_params) do
      {:ok, player} ->
        {:noreply,
         socket
         |> put_flash(:info, "Player updated successfully")
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
         |> put_flash(:info, "Player created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, player))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _player), do: ~p"/players"
  defp return_path("show", player), do: ~p"/players/#{player}"
end
