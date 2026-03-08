defmodule T3SystemWeb.LeagueLive.Form do
  use T3SystemWeb, :live_view

  alias T3System.Events
  alias T3System.Events.League

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>{gettext("Use this form to manage league records in your database.")}</:subtitle>
      </.header>

      <.form for={@form} id="league-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <footer>
          <.button phx-disable-with={gettext("Saving...")} variant="primary">
            {gettext("Save League")}
          </.button>
          <.button navigate={return_path(@return_to, @league)}>{gettext("Cancel")}</.button>
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
    league = Events.get_league!(id)

    socket
    |> assign(:page_title, gettext("Edit League"))
    |> assign(:league, league)
    |> assign(:form, to_form(Events.change_league(league)))
  end

  defp apply_action(socket, :new, _params) do
    league = %League{}

    socket
    |> assign(:page_title, gettext("New League"))
    |> assign(:league, league)
    |> assign(:form, to_form(Events.change_league(league)))
  end

  @impl true
  def handle_event("validate", %{"league" => league_params}, socket) do
    changeset = Events.change_league(socket.assigns.league, league_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"league" => league_params}, socket) do
    save_league(socket, socket.assigns.live_action, league_params)
  end

  defp save_league(socket, :edit, league_params) do
    case Events.update_league(socket.assigns.current_scope, socket.assigns.league, league_params) do
      {:ok, league} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("League updated successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to, league))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_league(socket, :new, league_params) do
    case Events.create_league(socket.assigns.current_scope, league_params) do
      {:ok, league} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("League created successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to, league))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _league), do: ~p"/leagues"
  defp return_path("show", league), do: ~p"/leagues/#{league}"
end
