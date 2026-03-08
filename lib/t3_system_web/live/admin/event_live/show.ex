defmodule T3SystemWeb.Admin.EventLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="events">
      <.header>
        Event {@event.id}
        <:subtitle>{gettext("This is a event record from your database.")}</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/events"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/events/#{@event}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> {gettext("Edit event")}
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title={gettext("Name")}>{@event.name}</:item>
        <:item title={gettext("Address")}>{@event.address}</:item>
        <:item title={gettext("Datetime")}>{@event.datetime}</:item>
        <:item title={gettext("League")}>{@event.league && @event.league.name}</:item>
        <:item title={gettext("Categories")}>
          <div class="flex flex-wrap gap-1 mt-1">
            <span :for={category <- @event.categories} class="badge badge-soft badge-primary">
              {category.name}
            </span>
          </div>
        </:item>
      </.list>
    </Layouts.settings>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Show Event"))
     |> assign(:event, Events.get_event!(id))}
  end
end
