defmodule T3SystemWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use T3SystemWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>
      <footer class="w-full bg-chrome px-4 py-6">
        <p class="text-center text-xs font-medium tracking-wide text-fg-muted uppercase">
          {gettext("Realização e apoio")}
        </p>
        <div class="mt-4 flex items-center justify-center gap-6">
          <img src="/images/t3.svg" alt="T3" />
          <img src="/images/sakay.svg" alt="Sakay" />
          <img src="/images/hideki.svg" alt="Hideki" />
        </div>
      </footer>
      <div
        :if={@current_scope}
        class="flex w-full items-center justify-center gap-4 border-t border-border bg-chrome px-4 py-2 text-center text-xs text-fg-muted"
      >
        Logged in as {@current_scope.user.email}
        <.link href={~p"/users/log-out"} method="delete" class="font-medium hover:text-fg">
          Log out
        </.link>
      </div>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders your app settings layout.

  ## Examples

      <Layouts.settings flash={@flash}>
        <h1>Content</h1>
      </Layouts.settings>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :active_item, :string, default: nil

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def settings(assigns) do
    ~H"""
    <%!-- Mobile sidebar (drawer), powered by @tailwindplus/elements --%>
    <el-dialog>
      <dialog id="sidebar" class="backdrop:bg-transparent lg:hidden">
        <el-dialog-backdrop class="fixed inset-0 bg-scrim transition-opacity duration-300 ease-linear data-closed:opacity-0">
        </el-dialog-backdrop>

        <div tabindex="0" class="fixed inset-0 flex focus:outline-none">
          <el-dialog-panel class="group/dialog-panel relative mr-16 flex w-full max-w-xs flex-1 transform transition duration-300 ease-in-out data-closed:-translate-x-full">
            <div class="absolute top-0 left-full flex w-16 justify-center pt-5 duration-300 ease-in-out group-data-closed/dialog-panel:opacity-0">
              <button
                type="button"
                command="close"
                commandfor="sidebar"
                class="-m-2.5 p-2.5 text-fg"
              >
                <span class="sr-only">{gettext("Close sidebar")}</span>
                <.icon name="hero-x-mark" class="size-6" />
              </button>
            </div>

            <div class="relative flex grow flex-col gap-y-5 overflow-y-auto bg-chrome px-6 pb-2">
              <div class="flex h-16 shrink-0 items-center">
                <img src="/images/t3.svg" alt="T3" class="size-8" />
              </div>
              <.settings_nav active_item={@active_item} />
            </div>
          </el-dialog-panel>
        </div>
      </dialog>
    </el-dialog>

    <%!-- Static sidebar for desktop --%>
    <div class="hidden lg:fixed lg:inset-y-0 lg:z-50 lg:flex lg:w-72 lg:flex-col">
      <div class="flex grow flex-col gap-y-5 overflow-y-auto border-r border-border bg-chrome px-6">
        <div class="flex h-16 shrink-0 items-center">
          <img src="/images/t3.svg" alt="T3" class="size-12" />
        </div>
        <.settings_nav active_item={@active_item} />
      </div>
    </div>

    <div class="sticky top-0 z-40 flex items-center gap-x-6 border-b border-border bg-chrome px-4 py-4 sm:px-6 lg:hidden">
      <button
        type="button"
        command="show-modal"
        commandfor="sidebar"
        class="-m-2.5 p-2.5 text-fg hover:text-fg-muted lg:hidden"
      >
        <span class="sr-only">{gettext("Open sidebar")}</span>
        <.icon name="hero-bars-3" class="size-6" />
      </button>
      <div class="flex-1 text-sm/6 font-semibold">
        {gettext("Settings")}
      </div>
    </div>

    <main class="py-10 lg:pl-72">
      <div class="px-4 sm:px-6 lg:px-8">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :active_item, :string, default: nil

  defp settings_nav(assigns) do
    ~H"""
    <nav class="flex flex-1 flex-col">
      <div class="text-xs/6 font-semibold text-fg-muted">{gettext("Config")}</div>
      <ul role="list" class="-mx-2 mt-2 space-y-1">
        <.config_item
          is_active={@active_item == "players"}
          item_char="P"
          item_name={gettext("Jogadores")}
          navigate={~p"/admin/players"}
        />
        <.config_item
          is_active={@active_item == "clubs"}
          item_char="C"
          item_name={gettext("Clubs")}
          navigate={~p"/admin/clubs"}
        />
        <.config_item
          is_active={@active_item == "events"}
          item_char="E"
          item_name={gettext("Events")}
          navigate={~p"/admin/events"}
        />
        <.config_item
          is_active={@active_item == "categories"}
          item_char="C"
          item_name={gettext("Categories")}
          navigate={~p"/admin/categories"}
        />
        <.config_item
          is_active={@active_item == "leagues"}
          item_char="L"
          item_name={gettext("Leagues")}
          navigate={~p"/admin/leagues"}
        />
      </ul>
    </nav>
    """
  end

  attr :is_active, :boolean, required: true
  attr :item_char, :string, required: true
  attr :item_name, :string, required: true
  attr :navigate, :string, required: true

  defp config_item(assigns) do
    ~H"""
    <li>
      <.link
        navigate={@navigate}
        aria-current={@is_active && "page"}
        class={[
          "group flex gap-x-3 rounded-control p-2 text-sm/6 font-semibold transition-colors",
          if(@is_active,
            do: "bg-primary/15 text-primary",
            else: "text-fg hover:bg-primary/5 hover:text-primary"
          )
        ]}
      >
        <span class={[
          "flex size-6 shrink-0 items-center justify-center rounded-control border text-[0.625rem] font-medium",
          if(@is_active,
            do: "border-primary",
            else: "border-border-strong group-hover:border-primary"
          )
        ]}>
          {@item_char}
        </span>
        <span class="truncate">{@item_name}</span>
      </.link>
    </li>
    """
  end
end
