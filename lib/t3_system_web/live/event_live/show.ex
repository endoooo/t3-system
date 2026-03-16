defmodule T3SystemWeb.EventLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Clubs
  alias T3System.Events
  alias T3System.Players
  alias T3System.Registrations
  alias T3System.Registrations.Registration

  @tabs ~w(overview matches groups knockout)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-4xl px-4 py-8">
        <%!-- Event header --%>
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-white">{@event.name}</h1>
          <div class="mt-1 flex flex-wrap gap-x-4 gap-y-1 text-sm text-gray-400">
            <span :if={@event.datetime}>{Calendar.strftime(@event.datetime, "%d/%m/%Y %H:%M")}</span>
            <span :if={@event.address}>{@event.address}</span>
            <span :if={@event.league}>{@event.league.name}</span>
          </div>
        </div>

        <%!-- Category selector --%>
        <div :if={@event.categories != []} class="mb-6 w-48">
          <.form for={@category_form} id="category-form" phx-change="switch_category">
            <.input
              field={@category_form[:category_id]}
              type="select"
              label={gettext("Category")}
              options={Enum.map(@event.categories, &{&1.name, &1.id})}
            />
          </.form>
        </div>

        <%!-- Tab nav --%>
        <div class="mb-6">
          <div class="border-b border-white/10">
            <nav aria-label={gettext("Tabs")} class="-mb-px flex">
              <.link
                :for={tab <- @tabs}
                patch={~p"/events/#{@event}?#{tab_params(@current_tab, @active_category, tab)}"}
                class={[
                  "w-1/4 border-b-2 px-1 py-4 text-center text-sm font-medium",
                  if(tab == @current_tab,
                    do: "border-indigo-400 text-indigo-400",
                    else: "border-transparent text-gray-400 hover:border-white/20 hover:text-gray-300"
                  )
                ]}
              >
                {tab_label(tab)}
              </.link>
            </nav>
          </div>
        </div>

        <%!-- Tab: Overview --%>
        <div :if={@current_tab == "overview"}>
          <div :if={@is_superuser} class="mb-4 flex justify-end">
            <.button phx-click="open_new_registration" variant="primary">
              <.icon name="hero-plus" /> {gettext("Add Registration")}
            </.button>
          </div>

          <ul
            :if={@active_category}
            id="registrations"
            phx-update="stream"
            class="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4"
          >
            <li
              :for={{id, reg} <- @streams.registrations}
              id={id}
              class="flex flex-col rounded-lg bg-white/5 text-center shadow-sm"
            >
              <div class="flex flex-1 flex-col p-6">
                <img
                  :if={reg.player.picture_url}
                  src={reg.player.picture_url}
                  alt={reg.player.name}
                  class="mx-auto size-24 shrink-0 rounded-full bg-gray-700 object-cover"
                />
                <div
                  :if={!reg.player.picture_url}
                  class="mx-auto flex size-24 shrink-0 items-center justify-center rounded-full bg-gray-700"
                >
                  <.icon name="hero-user" class="size-12 text-gray-400" />
                </div>
                <h3 class="mt-4 text-sm font-medium text-white">{reg.player.name}</h3>
                <p class="mt-1 text-xs text-gray-400">{reg.club.name}</p>
              </div>
              <div :if={@is_superuser} class="border-t border-white/10 px-4 py-2">
                <div class="flex justify-center gap-4">
                  <button
                    phx-click="open_edit_registration"
                    phx-value-id={reg.id}
                    class="text-xs text-indigo-400 hover:text-indigo-300"
                  >
                    {gettext("Edit")}
                  </button>
                  <button
                    phx-click="delete_registration"
                    phx-value-id={reg.id}
                    data-confirm={gettext("Are you sure?")}
                    class="text-xs text-red-400 hover:text-red-300"
                  >
                    {gettext("Remove")}
                  </button>
                </div>
              </div>
            </li>
          </ul>

          <p :if={!@active_category} class="text-gray-400 text-sm">
            {gettext("No category selected.")}
          </p>
        </div>

        <%!-- Other tabs: placeholder --%>
        <div :if={@current_tab != "overview"}>
          <p class="text-gray-400 text-sm">{gettext("Coming soon.")}</p>
        </div>

        <%!-- Modal --%>
        <div :if={@modal != nil} class="fixed inset-0 z-50">
          <%!-- Backdrop: sibling to content so clicks inside don't bubble here --%>
          <div class="absolute inset-0 bg-black/60" phx-click="close_modal"></div>
          <%!-- Content: positioned above backdrop, pointer-events on inner div only --%>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {if @modal == :new,
                    do: gettext("Add Registration"),
                    else: gettext("Edit Registration")}
                </h2>
                <button phx-click="close_modal" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <.form
                :if={@form}
                for={@form}
                id="registration-form"
                phx-change="validate"
                phx-submit="save_registration"
              >
                <.input
                  field={@form[:player_id]}
                  type="select"
                  label={gettext("Player")}
                  options={Enum.map(@players, &{&1.name, &1.id})}
                  prompt={gettext("Select a player")}
                />
                <.input
                  field={@form[:club_id]}
                  type="select"
                  label={gettext("Club")}
                  options={Enum.map(@clubs, &{&1.name, &1.id})}
                  prompt={gettext("Select a club")}
                />
                <input type="hidden" name="registration[event_id]" value={@event.id} />
                <input
                  type="hidden"
                  name="registration[category_id]"
                  value={@active_category && @active_category.id}
                />
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_modal">{gettext("Cancel")}</.button>
                  <.button type="submit" variant="primary">{gettext("Save")}</.button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    event = Events.get_event!(id)
    is_superuser = superuser?(socket.assigns)

    socket =
      socket
      |> assign(:page_title, event.name)
      |> assign(:event, event)
      |> assign(:tabs, @tabs)
      |> assign(:is_superuser, is_superuser)
      |> assign(:category_form, to_form(%{"category_id" => nil}, as: :category))
      |> assign(:modal, nil)
      |> assign(:form, nil)
      |> stream(:registrations, [])

    socket =
      if is_superuser do
        socket
        |> assign(:players, Players.list_player())
        |> assign(:clubs, Clubs.list_clubs())
      else
        socket
        |> assign(:players, [])
        |> assign(:clubs, [])
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    event = socket.assigns.event
    tab = if params["tab"] in @tabs, do: params["tab"], else: "overview"

    active_category =
      case Integer.parse(params["category_id"] || "") do
        {id, ""} -> Enum.find(event.categories, &(&1.id == id))
        _ -> List.first(event.categories)
      end

    category_form =
      to_form(%{"category_id" => active_category && to_string(active_category.id)}, as: :category)

    socket =
      socket
      |> assign(:current_tab, tab)
      |> assign(:active_category, active_category)
      |> assign(:category_form, category_form)

    socket =
      if tab == "overview" && active_category do
        stream(
          socket,
          :registrations,
          Registrations.list_registrations_by_event_and_category(event.id, active_category),
          reset: true
        )
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_category", %{"category" => %{"category_id" => id}}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/events/#{socket.assigns.event}?tab=#{socket.assigns.current_tab}&category_id=#{id}"
     )}
  end

  def handle_event("open_new_registration", _params, socket) do
    form =
      Registrations.change_registration(%Registration{})
      |> to_form()

    {:noreply, assign(socket, modal: :new, form: form)}
  end

  def handle_event("open_edit_registration", %{"id" => id}, socket) do
    reg = Registrations.get_registration!(id)

    form =
      Registrations.change_registration(reg)
      |> to_form()

    {:noreply, assign(socket, modal: {:edit, reg}, form: form)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form: nil)}
  end

  def handle_event("validate", %{"registration" => attrs}, socket) do
    form =
      case socket.assigns.modal do
        {:edit, reg} -> Registrations.change_registration(reg, attrs)
        _ -> Registrations.change_registration(%Registrations.Registration{}, attrs)
      end
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save_registration", %{"registration" => attrs}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.modal do
        {:edit, reg} -> Registrations.update_registration(scope, reg, attrs)
        _ -> Registrations.create_registration(scope, attrs)
      end

    case result do
      {:ok, reg} ->
        reg = Registrations.get_registration!(reg.id)

        {:noreply,
         socket
         |> stream_insert(:registrations, reg)
         |> assign(modal: nil, form: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete_registration", %{"id" => id}, socket) do
    reg = Registrations.get_registration!(id)
    {:ok, _} = Registrations.delete_registration(socket.assigns.current_scope, reg)
    {:noreply, stream_delete(socket, :registrations, reg)}
  end

  # Private helpers

  defp superuser?(%{current_scope: %{user: %{role: "superuser"}}}), do: true
  defp superuser?(_), do: false

  defp tab_label("overview"), do: gettext("Overview")
  defp tab_label("matches"), do: gettext("Matches")
  defp tab_label("groups"), do: gettext("Groups")
  defp tab_label("knockout"), do: gettext("Knockout")

  defp tab_params(current_tab, active_category, tab) do
    base = %{"tab" => tab}

    category_id =
      if tab == current_tab,
        do: active_category && active_category.id,
        else: active_category && active_category.id

    if category_id, do: Map.put(base, "category_id", category_id), else: base
  end
end
