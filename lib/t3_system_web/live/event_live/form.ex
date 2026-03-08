defmodule T3SystemWeb.EventLive.Form do
  use T3SystemWeb, :live_view

  alias T3System.Categories
  alias T3System.Events
  alias T3System.Events.Event

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>{gettext("Use this form to manage event records in your database.")}</:subtitle>
      </.header>

      <.form for={@form} id="event-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label={gettext("Name")} />
        <.input field={@form[:address]} type="textarea" label={gettext("Address")} />
        <.input field={@form[:datetime]} type="datetime-local" label={gettext("Datetime")} />
        <div class="fieldset mb-6">
          <label class="label mb-1">{gettext("Categories")}</label>
          <input type="hidden" name="event[category_ids][]" value="" />
          <div class="flex flex-wrap gap-2">
            <input
              :for={category <- @all_categories}
              type="checkbox"
              class="btn"
              name="event[category_ids][]"
              value={category.id}
              checked={category.id in @selected_category_ids}
              aria-label={category.name}
            />
          </div>
        </div>
        <footer>
          <.button phx-disable-with={gettext("Saving...")} variant="primary">
            {gettext("Save Event")}
          </.button>
          <.button navigate={return_path(@return_to, @event)}>{gettext("Cancel")}</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    event = Events.get_event!(id)

    socket
    |> assign(:page_title, gettext("Edit Event"))
    |> assign(:event, event)
    |> assign(:form, to_form(Events.change_event(event)))
    |> assign(:all_categories, Categories.list_categories())
    |> assign(:selected_category_ids, Enum.map(event.categories, & &1.id))
  end

  defp apply_action(socket, :new, _params) do
    event = %Event{categories: []}

    socket
    |> assign(:page_title, gettext("New Event"))
    |> assign(:event, event)
    |> assign(:form, to_form(Events.change_event(event)))
    |> assign(:all_categories, Categories.list_categories())
    |> assign(:selected_category_ids, [])
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    selected_ids =
      event_params
      |> Map.get("category_ids", [])
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_integer/1)

    changeset = Events.change_event(socket.assigns.event, event_params)

    {:noreply,
     socket
     |> assign(:selected_category_ids, selected_ids)
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"event" => event_params}, socket) do
    save_event(socket, socket.assigns.live_action, event_params)
  end

  defp save_event(socket, :edit, event_params) do
    case Events.update_event(socket.assigns.current_scope, socket.assigns.event, event_params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Event updated successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to, event))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_event(socket, :new, event_params) do
    case Events.create_event(socket.assigns.current_scope, event_params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Event created successfully"))
         |> push_navigate(to: return_path(socket.assigns.return_to, event))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _event), do: ~p"/events"
  defp return_path("show", event), do: ~p"/events/#{event}"
end
