defmodule T3SystemWeb.Admin.EventLive.Index do
  use T3SystemWeb, :live_view

  alias T3System.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="events">
      <.header>
        {gettext("Listing Events")}
        <:actions>
          <.button variant="primary" navigate={~p"/admin/events/new"}>
            <.icon name="hero-plus" /> {gettext("New Event")}
          </.button>
        </:actions>
      </.header>

      <.table
        id="events"
        rows={@streams.events}
        row_click={fn {_id, event} -> JS.navigate(~p"/admin/events/#{event}") end}
      >
        <:col :let={{_id, event}} label={gettext("Name")}>{event.name}</:col>
        <:col :let={{_id, event}} label={gettext("Address")}>{event.address}</:col>
        <:col :let={{_id, event}} label={gettext("Datetime")}>{event.datetime}</:col>
        <:col :let={{_id, event}} label={gettext("League")}>{event.league && event.league.name}</:col>
        <:col :let={{_id, event}} label={gettext("Categories")}>
          <div class="flex flex-wrap gap-1">
            <span :for={category <- event.categories} class="badge badge-soft badge-primary">
              {category.name}
            </span>
          </div>
        </:col>
        <:action :let={{_id, event}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/events/#{event}"}>{gettext("Show")}</.link>
          </div>
          <.link navigate={~p"/admin/events/#{event}/edit"}>{gettext("Edit")}</.link>
        </:action>
        <:action :let={{id, event}}>
          <.link
            phx-click={JS.push("delete", value: %{id: event.id}) |> hide("##{id}")}
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
     |> assign(:page_title, gettext("Listing Events"))
     |> stream(:events, list_events())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    event = Events.get_event!(id)
    {:ok, _} = Events.delete_event(socket.assigns.current_scope, event)

    {:noreply, stream_delete(socket, :events, event)}
  end

  defp list_events do
    Events.list_events()
  end
end
