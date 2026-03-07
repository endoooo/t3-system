defmodule T3SystemWeb.PlayerLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Players

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Player {@player.id}
        <:subtitle>This is a player record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/players"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/players/#{@player}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit player
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@player.name}</:item>
        <:item title="Birthdate">{@player.birthdate}</:item>
        <:item title="Picture url">{@player.picture_url}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Player")
     |> assign(:player, Players.get_player!(id))}
  end
end
