defmodule T3SystemWeb.Admin.ClubLive.Form do
  use T3SystemWeb, :live_view

  alias T3System.Clubs
  alias T3System.Clubs.Club

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="clubs">
      <.header>
        {@page_title}
        <:subtitle>{gettext("Use this form to manage club records in your database.")}</:subtitle>
      </.header>

      <.form for={@form} id="club-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <footer>
          <.button phx-disable-with={gettext("Saving...")} variant="primary">
            {gettext("Save Club")}
          </.button>
          <.button navigate={return_path(@return_to, @club)}>{gettext("Cancel")}</.button>
        </footer>
      </.form>
    </Layouts.settings>
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
    club = Clubs.get_club!(id)

    socket
    |> assign(:page_title, gettext("Edit Club"))
    |> assign(:club, club)
    |> assign(:form, to_form(Clubs.change_club(club)))
  end

  defp apply_action(socket, :new, _params) do
    club = %Club{}

    socket
    |> assign(:page_title, gettext("New Club"))
    |> assign(:club, club)
    |> assign(:form, to_form(Clubs.change_club(club)))
  end

  @impl true
  def handle_event("validate", %{"club" => club_params}, socket) do
    changeset = Clubs.change_club(socket.assigns.club, club_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"club" => club_params}, socket) do
    save_club(socket, socket.assigns.live_action, club_params)
  end

  defp save_club(socket, :edit, club_params) do
    case Clubs.update_club(socket.assigns.current_scope, socket.assigns.club, club_params) do
      {:ok, club} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Club updated successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to, club))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_club(socket, :new, club_params) do
    case Clubs.create_club(socket.assigns.current_scope, club_params) do
      {:ok, club} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Club created successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to, club))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _club), do: ~p"/admin/clubs"
  defp return_path("show", club), do: ~p"/admin/clubs/#{club}"
end
