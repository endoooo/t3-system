defmodule T3SystemWeb.PlayerLive.Index do
  use T3SystemWeb, :live_view

  alias T3System.Players

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {gettext("Listing Player")}
        <:actions>
          <.button variant="primary" navigate={~p"/players/new"}>
            <.icon name="hero-plus" /> {gettext("New Player")}
          </.button>
        </:actions>
      </.header>

      <.table
        id="player"
        rows={@streams.player_collection}
        row_click={fn {_id, player} -> JS.navigate(~p"/players/#{player}") end}
      >
        <:col :let={{_id, player}} label={gettext("Name")}>{player.name}</:col>
        <:col :let={{_id, player}} label={gettext("Birthdate")}>{player.birthdate}</:col>
        <:col :let={{_id, player}} label={gettext("Picture url")}>{player.picture_url}</:col>
        <:action :let={{_id, player}}>
          <div class="sr-only">
            <.link navigate={~p"/players/#{player}"}>{gettext("Show")}</.link>
          </div>
          <.link navigate={~p"/players/#{player}/edit"}>{gettext("Edit")}</.link>
        </:action>
        <:action :let={{id, player}}>
          <.link
            phx-click={JS.push("delete", value: %{id: player.id}) |> hide("##{id}")}
            data-confirm={gettext("Are you sure?")}
          >
            {gettext("Delete")}
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Listing Player"))
     |> stream(:player_collection, list_player())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    player = Players.get_player!(id)
    {:ok, _} = Players.delete_player(socket.assigns.current_scope, player)

    {:noreply, stream_delete(socket, :player_collection, player)}
  end

  defp list_player do
    Players.list_player()
  end
end
