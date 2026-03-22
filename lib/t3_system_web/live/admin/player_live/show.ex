defmodule T3SystemWeb.Admin.PlayerLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Players

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="players">
      <.header>
        Player {@player.id}
        <:subtitle>{gettext("This is a player record from your database.")}</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/players"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/players/#{@player}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> {gettext("Edit player")}
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title={gettext("Nome")}>{@player.name}</:item>
        <:item title={gettext("Birthdate")}>{@player.birthdate}</:item>
        <:item title={gettext("Picture url")}>{@player.picture_url}</:item>
      </.list>
    </Layouts.settings>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Show Player"))
     |> assign(:player, Players.get_player!(id))}
  end
end
