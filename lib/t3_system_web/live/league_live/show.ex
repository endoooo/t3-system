defmodule T3SystemWeb.LeagueLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="leagues">
      <.header>
        League {@league.id}
        <:subtitle>{gettext("This is a league record from your database.")}</:subtitle>
        <:actions>
          <.button navigate={~p"/leagues"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/leagues/#{@league}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> {gettext("Edit league")}
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title={gettext("Name")}>{@league.name}</:item>
      </.list>
    </Layouts.settings>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Show League"))
     |> assign(:league, Events.get_league!(id))}
  end
end
