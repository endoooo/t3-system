defmodule T3SystemWeb.Admin.ClubLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Clubs

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="clubs">
      <.header>
        Club {@club.id}
        <:subtitle>{gettext("This is a club record from your database.")}</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/clubs"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/clubs/#{@club}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> {gettext("Edit club")}
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title={gettext("Name")}>{@club.name}</:item>
      </.list>
    </Layouts.settings>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Show Club"))
     |> assign(:club, Clubs.get_club!(id))}
  end
end
