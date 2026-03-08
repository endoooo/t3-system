defmodule T3SystemWeb.CategoryLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Categories

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.settings flash={@flash} active_item="categories">
      <.header>
        {gettext("Category %{id}", id: @category.id)}
        <:subtitle>{gettext("This is a category record from your database.")}</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/categories"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/categories/#{@category}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> {gettext("Edit category")}
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title={gettext("Name")}>{@category.name}</:item>
      </.list>
    </Layouts.settings>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Show Category"))
     |> assign(:category, Categories.get_category!(id))}
  end
end
