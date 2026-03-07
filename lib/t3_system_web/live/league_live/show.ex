defmodule T3SystemWeb.LeagueLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        League {@league.id}
        <:subtitle>This is a league record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/leagues"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/leagues/#{@league}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit league
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@league.name}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show League")
     |> assign(:league, Events.get_league!(id))}
  end
end
