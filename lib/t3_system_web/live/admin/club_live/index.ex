defmodule T3SystemWeb.Admin.ClubLive.Index do
  use T3SystemWeb, :live_view

  alias T3System.Clubs

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="clubs">
      <.header>
        {gettext("Listing Clubs")}
        <:actions>
          <.button variant="primary" navigate={~p"/admin/clubs/new"}>
            <.icon name="hero-plus" /> {gettext("New Club")}
          </.button>
        </:actions>
      </.header>

      <.table
        id="clubs"
        rows={@streams.clubs}
        row_click={fn {_id, club} -> JS.navigate(~p"/admin/clubs/#{club}") end}
      >
        <:col :let={{_id, club}} label={gettext("Name")}>{club.name}</:col>
        <:action :let={{_id, club}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/clubs/#{club}"}>{gettext("Show")}</.link>
          </div>
          <.link navigate={~p"/admin/clubs/#{club}/edit"}>{gettext("Edit")}</.link>
        </:action>
        <:action :let={{id, club}}>
          <.link
            phx-click={JS.push("delete", value: %{id: club.id}) |> hide("##{id}")}
            data-confirm={gettext("Are you sure?")}
          >
            {gettext("Delete")}
          </.link>
        </:action>
      </.table>
    </Layouts.settings>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Listing Clubs"))
     |> stream(:clubs, Clubs.list_clubs())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    club = Clubs.get_club!(id)
    {:ok, _} = Clubs.delete_club(socket.assigns.current_scope, club)

    {:noreply, stream_delete(socket, :clubs, club)}
  end
end
