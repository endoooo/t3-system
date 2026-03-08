defmodule T3SystemWeb.CategoryLive.Index do
  use T3SystemWeb, :live_view

  alias T3System.Categories

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="categories">
      <.header>
        {gettext("Listing Categories")}
        <:actions>
          <.button variant="primary" navigate={~p"/categories/new"}>
            <.icon name="hero-plus" /> {gettext("New Category")}
          </.button>
        </:actions>
      </.header>

      <.table
        id="categories"
        rows={@streams.categories}
        row_click={fn {_id, category} -> JS.navigate(~p"/categories/#{category}") end}
      >
        <:col :let={{_id, category}} label={gettext("Name")}>{category.name}</:col>
        <:action :let={{_id, category}}>
          <div class="sr-only">
            <.link navigate={~p"/categories/#{category}"}>{gettext("Show")}</.link>
          </div>
          <.link navigate={~p"/categories/#{category}/edit"}>{gettext("Edit")}</.link>
        </:action>
        <:action :let={{id, category}}>
          <.link
            phx-click={JS.push("delete", value: %{id: category.id}) |> hide("##{id}")}
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
     |> assign(:page_title, gettext("Listing Categories"))
     |> stream(:categories, list_categories())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    category = Categories.get_category!(id)
    {:ok, _} = Categories.delete_category(socket.assigns.current_scope, category)

    {:noreply, stream_delete(socket, :categories, category)}
  end

  defp list_categories do
    Categories.list_categories()
  end
end
