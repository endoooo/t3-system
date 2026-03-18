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
    <main>
      {render_slot(@inner_block)}
    </main>

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
    <!-- Include this script tag or install `@tailwindplus/elements` via npm: -->
    <!-- <script src="https://cdn.jsdelivr.net/npm/@tailwindplus/elements@1" type="module"></script> -->
    <!--
      This example requires updating your template:

      ```
      <html class="h-full bg-white dark:bg-gray-900">
      <body class="h-full">
      ```
    -->

    <el-dialog>
      <dialog id="sidebar" class="backdrop:bg-transparent lg:hidden">
        <el-dialog-backdrop class="fixed inset-0 bg-gray-900/80 transition-opacity duration-300 ease-linear data-closed:opacity-0">
        </el-dialog-backdrop>

        <div tabindex="0" class="fixed inset-0 flex focus:outline-none">
          <el-dialog-panel class="group/dialog-panel relative mr-16 flex w-full max-w-xs flex-1 transform transition duration-300 ease-in-out data-closed:-translate-x-full">
            <div class="absolute top-0 left-full flex w-16 justify-center pt-5 duration-300 ease-in-out group-data-closed/dialog-panel:opacity-0">
              <button type="button" command="close" commandfor="sidebar" class="-m-2.5 p-2.5">
                <span class="sr-only">Close sidebar</span>
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  data-slot="icon"
                  aria-hidden="true"
                  class="size-6 text-white"
                >
                  <path d="M6 18 18 6M6 6l12 12" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              </button>
            </div>
            
    <!-- Sidebar component, swap this element with another sidebar if you like -->
            <div class="relative flex grow flex-col gap-y-5 overflow-y-auto bg-white px-6 pb-2">
              <div class="relative flex h-16 shrink-0 items-center">
                <img
                  src="https://tailwindcss.com/plus-assets/img/logos/mark.svg?color=indigo&shade=600"
                  alt="Your Company"
                  class="h-8 w-auto"
                />
              </div>
              <nav class="relative flex flex-1 flex-col">
                <ul role="list" class="flex flex-1 flex-col gap-y-7">
                  <%!-- <li>
                    <ul role="list" class="-mx-2 space-y-1">
                      <li>
                        <!-- Current: "bg-gray-50 dark:bg-white/5 text-indigo-600 dark:text-white", Default: "text-gray-700 dark:text-gray-400 hover:text-indigo-600 dark:hover:text-white hover:bg-gray-50 dark:hover:bg-white/5" -->
                        <a
                          href="#"
                          class="group flex gap-x-3 rounded-md bg-gray-50 p-2 text-sm/6 font-semibold text-indigo-600 dark:bg-white/5 dark:text-white"
                        >
                          <svg
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="1.5"
                            data-slot="icon"
                            aria-hidden="true"
                            class="size-6 shrink-0 text-indigo-600 dark:text-white"
                          >
                            <path
                              d="m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
                              stroke-linecap="round"
                              stroke-linejoin="round"
                            />
                          </svg>
                          Dashboard
                        </a>
                      </li>
                      <li>
                        <a
                          href="#"
                          class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                        >
                          <svg
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="1.5"
                            data-slot="icon"
                            aria-hidden="true"
                            class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                          >
                            <path
                              d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z"
                              stroke-linecap="round"
                              stroke-linejoin="round"
                            />
                          </svg>
                          Team
                        </a>
                      </li>
                      <li>
                        <a
                          href="#"
                          class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                        >
                          <svg
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="1.5"
                            data-slot="icon"
                            aria-hidden="true"
                            class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                          >
                            <path
                              d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z"
                              stroke-linecap="round"
                              stroke-linejoin="round"
                            />
                          </svg>
                          Projects
                        </a>
                      </li>
                      <li>
                        <a
                          href="#"
                          class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                        >
                          <svg
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="1.5"
                            data-slot="icon"
                            aria-hidden="true"
                            class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                          >
                            <path
                              d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5"
                              stroke-linecap="round"
                              stroke-linejoin="round"
                            />
                          </svg>
                          Calendar
                        </a>
                      </li>
                      <li>
                        <a
                          href="#"
                          class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                        >
                          <svg
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="1.5"
                            data-slot="icon"
                            aria-hidden="true"
                            class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                          >
                            <path
                              d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 0 1-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 0 1 1.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 0 0-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 0 1-1.125-1.125v-9.25m12 6.625v-1.875a3.375 3.375 0 0 0-3.375-3.375h-1.5a1.125 1.125 0 0 1-1.125-1.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H9.75"
                              stroke-linecap="round"
                              stroke-linejoin="round"
                            />
                          </svg>
                          Documents
                        </a>
                      </li>
                      <li>
                        <a
                          href="#"
                          class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                        >
                          <svg
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            stroke-width="1.5"
                            data-slot="icon"
                            aria-hidden="true"
                            class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                          >
                            <path
                              d="M10.5 6a7.5 7.5 0 1 0 7.5 7.5h-7.5V6Z"
                              stroke-linecap="round"
                              stroke-linejoin="round"
                            />
                            <path
                              d="M13.5 10.5H21A7.5 7.5 0 0 0 13.5 3v7.5Z"
                              stroke-linecap="round"
                              stroke-linejoin="round"
                            />
                          </svg>
                          Reports
                        </a>
                      </li>
                    </ul>
                  </li> --%>
                  <li>
                    <div class="text-xs/6 font-semibold text-gray-400">{gettext("Settings")}</div>
                    <ul role="list" class="-mx-2 mt-2 space-y-1">
                      <.config_item
                        is_active={@active_item == "players"}
                        item_char="P"
                        item_name={gettext("Players")}
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
                  </li>
                </ul>
              </nav>
            </div>
          </el-dialog-panel>
        </div>
      </dialog>
    </el-dialog>

    <!-- Static sidebar for desktop -->
    <div class="hidden lg:fixed lg:inset-y-0 lg:z-50 lg:flex lg:w-72 lg:flex-col">
      <!-- Sidebar component, swap this element with another sidebar if you like -->
      <div class="flex grow flex-col gap-y-5 overflow-y-auto border-r border-gray-200 bg-white px-6">
        <div class="flex h-16 shrink-0 items-center">
          <img
            src="https://tailwindcss.com/plus-assets/img/logos/mark.svg?color=indigo&shade=600"
            alt="Your Company"
            class="h-8 w-auto"
          />
        </div>
        <nav class="flex flex-1 flex-col">
          <ul role="list" class="flex flex-1 flex-col gap-y-7">
            <li>
              <ul role="list" class="flex flex-1 flex-col gap-y-7">
                <%!-- <li>
                  <ul role="list" class="-mx-2 space-y-1">
                    <li>
                      <!-- Current: "bg-gray-50 dark:bg-white/5 text-indigo-600 dark:text-white", Default: "text-gray-700 dark:text-gray-400 hover:text-indigo-600 dark:hover:text-white hover:bg-gray-50 dark:hover:bg-white/5" -->
                      <a
                        href="#"
                        class="group flex gap-x-3 rounded-md bg-gray-50 p-2 text-sm/6 font-semibold text-indigo-600 dark:bg-white/5 dark:text-white"
                      >
                        <svg
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          data-slot="icon"
                          aria-hidden="true"
                          class="size-6 shrink-0 text-indigo-600 dark:text-white"
                        >
                          <path
                            d="m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                        </svg>
                        Dashboard
                      </a>
                    </li>
                    <li>
                      <a
                        href="#"
                        class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                      >
                        <svg
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          data-slot="icon"
                          aria-hidden="true"
                          class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                        >
                          <path
                            d="M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                        </svg>
                        Team
                      </a>
                    </li>
                    <li>
                      <a
                        href="#"
                        class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                      >
                        <svg
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          data-slot="icon"
                          aria-hidden="true"
                          class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                        >
                          <path
                            d="M2.25 12.75V12A2.25 2.25 0 0 1 4.5 9.75h15A2.25 2.25 0 0 1 21.75 12v.75m-8.69-6.44-2.12-2.12a1.5 1.5 0 0 0-1.061-.44H4.5A2.25 2.25 0 0 0 2.25 6v12a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9a2.25 2.25 0 0 0-2.25-2.25h-5.379a1.5 1.5 0 0 1-1.06-.44Z"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                        </svg>
                        Projects
                      </a>
                    </li>
                    <li>
                      <a
                        href="#"
                        class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                      >
                        <svg
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          data-slot="icon"
                          aria-hidden="true"
                          class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                        >
                          <path
                            d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                        </svg>
                        Calendar
                      </a>
                    </li>
                    <li>
                      <a
                        href="#"
                        class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                      >
                        <svg
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          data-slot="icon"
                          aria-hidden="true"
                          class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                        >
                          <path
                            d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 0 1-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 0 1 1.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 0 0-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 0 1-1.125-1.125v-9.25m12 6.625v-1.875a3.375 3.375 0 0 0-3.375-3.375h-1.5a1.125 1.125 0 0 1-1.125-1.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H9.75"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                        </svg>
                        Documents
                      </a>
                    </li>
                    <li>
                      <a
                        href="#"
                        class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-gray-700 hover:bg-gray-50 hover:text-indigo-600 dark:text-gray-400 dark:hover:bg-white/5 dark:hover:text-white"
                      >
                        <svg
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          data-slot="icon"
                          aria-hidden="true"
                          class="size-6 shrink-0 text-gray-400 group-hover:text-indigo-600 dark:group-hover:text-white"
                        >
                          <path
                            d="M10.5 6a7.5 7.5 0 1 0 7.5 7.5h-7.5V6Z"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                          <path
                            d="M13.5 10.5H21A7.5 7.5 0 0 0 13.5 3v7.5Z"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                        </svg>
                        Reports
                      </a>
                    </li>
                  </ul>
                </li> --%>
                <li>
                  <div class="text-xs/6 font-semibold text-gray-400">{gettext("Config")}</div>
                  <ul role="list" class="-mx-2 mt-2 space-y-1">
                    <.config_item
                      is_active={@active_item == "players"}
                      item_char="P"
                      item_name={gettext("Players")}
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
                </li>
              </ul>
            </li>
            <%!-- <li class="-mx-6 mt-auto">
              <a
                href="#"
                class="flex items-center gap-x-4 px-6 py-3 text-sm/6 font-semibold text-gray-900 hover:bg-gray-50 dark:text-white dark:hover:bg-white/5"
              >
                <img
                  src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80"
                  alt=""
                  class="size-8 rounded-full bg-gray-50 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10"
                />
                <span class="sr-only">Your profile</span>
                <span aria-hidden="true">Tom Cook</span>
              </a>
            </li> --%>
          </ul>
        </nav>
      </div>
    </div>

    <div class="sticky top-0 z-40 flex items-center gap-x-6 bg-white px-4 py-4 shadow-xs sm:px-6 lg:hidden">
      <button
        type="button"
        command="show-modal"
        commandfor="sidebar"
        class="-m-2.5 p-2.5 text-gray-700 hover:text-gray-900 lg:hidden"
      >
        <span class="sr-only">{gettext("Open sidebar")}</span>
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          data-slot="icon"
          aria-hidden="true"
          class="size-6"
        >
          <path
            d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </button>
      <div class="flex-1 text-sm/6 font-semibold text-gray-900">
        {gettext("Settings")}
      </div>
      <%!-- <a href="#">
        <span class="sr-only">Your profile</span>
        <img
          src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80"
          alt=""
          class="size-8 rounded-full bg-gray-50 outline -outline-offset-1 outline-black/5 dark:bg-gray-800 dark:outline-white/10"
        />
      </a> --%>
    </div>

    <main class="py-10 lg:pl-72">
      <div class="px-4 sm:px-6 lg:px-8">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :is_active, :boolean, required: true
  attr :item_char, :string, required: true
  attr :item_name, :string, required: true
  attr :navigate, :string, required: true

  defp config_item(assigns) do
    ~H"""
    <li>
      <!-- Current: "bg-gray-50 dark:bg-white/5 text-indigo-600 dark:text-white", Default: "text-gray-700 dark:text-gray-400 hover:text-indigo-600 dark:hover:text-white hover:bg-gray-50 dark:hover:bg-white/5" -->
      <.link
        navigate={@navigate}
        class={[
          "group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold",
          if(@is_active,
            do: "bg-gray-50 text-indigo-600",
            else: "text-gray-700 hover:bg-gray-50 hover:text-indigo-600"
          )
        ]}
      >
        <span class="flex size-6 shrink-0 items-center justify-center rounded-lg border border-gray-200 bg-white text-[0.625rem] font-medium text-gray-400 group-hover:border-indigo-600 group-hover:text-indigo-600">
          {@item_char}
        </span>
        <span class="truncate">{@item_name}</span>
      </.link>
    </li>
    """
  end
end
