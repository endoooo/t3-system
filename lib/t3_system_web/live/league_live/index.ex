defmodule T3SystemWeb.LeagueLive.Index do
  use T3SystemWeb, :live_view

  alias T3System.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Leagues
        <:actions>
          <.button variant="primary" navigate={~p"/leagues/new"}>
            <.icon name="hero-plus" /> New League
          </.button>
        </:actions>
      </.header>

      <.table
        id="leagues"
        rows={@streams.leagues}
        row_click={fn {_id, league} -> JS.navigate(~p"/leagues/#{league}") end}
      >
        <:col :let={{_id, league}} label="Name">{league.name}</:col>
        <:action :let={{_id, league}}>
          <div class="sr-only">
            <.link navigate={~p"/leagues/#{league}"}>Show</.link>
          </div>
          <.link navigate={~p"/leagues/#{league}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, league}}>
          <.link
            phx-click={JS.push("delete", value: %{id: league.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
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
     |> assign(:page_title, "Listing Leagues")
     |> stream(:leagues, list_leagues())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    league = Events.get_league!(id)
    {:ok, _} = Events.delete_league(socket.assigns.current_scope, league)

    {:noreply, stream_delete(socket, :leagues, league)}
  end

  defp list_leagues do
    Events.list_leagues()
  end
end
