defmodule T3SystemWeb.EventLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Clubs
  alias T3System.Events
  alias T3System.Matches
  alias T3System.Matches.Group
  alias T3System.Matches.Stage
  alias T3System.Players
  alias T3System.Registrations
  alias T3System.Registrations.Registration
  alias T3System.Tables
  alias T3System.Tables.Table

  @fixed_tabs ~w(management overview matches)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-4xl">
        <%!-- Event header --%>
        <div class="p-8">
          <h1 class="text-2xl font-display font-black mb-6">{@event.name}</h1>
          <div :if={@event.datetime} class="flex items-center gap-2 mb-2">
            <.icon name="hero-calendar-mini" />
            <span>{Calendar.strftime(@event.datetime, "%d/%m/%Y %H:%M")}</span>
          </div>
          <span :if={@event.address} class="text-sm">{@event.address}</span>

          <%!-- Category selector --%>
          <div :if={@event.categories != []} class="mt-6">
            <.form for={@category_form} id="category-form" phx-change="switch_category">
              <.input
                field={@category_form[:category_id]}
                type="select"
                label={gettext("Category")}
                options={Enum.map(@event.categories, &{&1.name, &1.id})}
              />
            </.form>
          </div>
        </div>

        <%!-- Tab nav --%>
        <div class="border-b border-slate-100 overflow-x-auto">
          <nav
            aria-label={gettext("Tabs")}
            class="flex gap-4 pl-8 whitespace-nowrap after:content-[''] after:shrink-0 after:w-8"
          >
            <.link
              :for={tab <- @tabs}
              patch={~p"/events/#{@event}?#{tab_params(@current_tab, @active_category, tab)}"}
              class={[
                "border-b-4 py-2 text-center text-sm",
                if(tab == @current_tab,
                  do: "border-sky-400 text-sky-400 font-bold",
                  else:
                    "border-transparent text-slate-100/60 hover:border-white/20 hover:text-gray-300"
                )
              ]}
            >
              {tab_label(tab, @stages)}
            </.link>
            <%!-- Add stage button (superuser only) --%>
            <button
              :if={@is_superuser and @active_category}
              phx-click="open_new_stage"
              class="border-b-4 border-transparent py-2 text-center text-sm text-slate-100/40 hover:text-slate-100/60"
            >
              <.icon name="hero-plus-mini" class="size-4" />
            </button>
          </nav>
        </div>

        <%!-- Tab: Management --%>
        <div :if={@current_tab == "management" and @is_superuser} class="p-8">
          <%!-- Dashboard Metrics --%>
          <div class="mb-8 space-y-4">
            <%!-- Games per category --%>
            <div class="rounded-lg bg-slate-800 p-4">
              <h3 class="text-sm font-semibold text-slate-300 mb-3">
                {gettext("Jogos por categoria")}
              </h3>
              <div :if={@dashboard_metrics.per_category == []} class="text-sm text-slate-500">
                {gettext("Nenhum jogo registrado.")}
              </div>
              <div class="space-y-2">
                <div
                  :for={row <- @dashboard_metrics.per_category}
                  class="flex items-center gap-3"
                >
                  <span class="w-28 shrink-0 truncate text-sm text-slate-300">
                    {row.category_name}
                  </span>
                  <div class="flex-1 h-5 rounded bg-slate-700 overflow-hidden">
                    <div
                      class="h-full rounded bg-sky-500"
                      style={"width: #{bar_pct(row.count, max_count(@dashboard_metrics.per_category))}%"}
                    >
                    </div>
                  </div>
                  <span class="w-8 text-right text-sm font-mono text-slate-400">{row.count}</span>
                </div>
              </div>
            </div>

            <%!-- Finished vs unfinished --%>
            <div class="rounded-lg bg-slate-800 p-4">
              <h3 class="text-sm font-semibold text-slate-300 mb-3">
                {gettext("Jogos finalizados vs. pendentes")}
              </h3>
              <% total =
                @dashboard_metrics.by_status.finished + @dashboard_metrics.by_status.unfinished %>
              <div :if={total == 0} class="text-sm text-slate-500">
                {gettext("Nenhum jogo registrado.")}
              </div>
              <div :if={total > 0} class="space-y-2">
                <div class="flex items-center gap-3">
                  <span class="w-28 shrink-0 text-sm text-slate-300">{gettext("Finalizados")}</span>
                  <div class="flex-1 h-5 rounded bg-slate-700 overflow-hidden">
                    <div
                      class="h-full rounded bg-green-500"
                      style={"width: #{bar_pct(@dashboard_metrics.by_status.finished, total)}%"}
                    >
                    </div>
                  </div>
                  <span class="w-8 text-right text-sm font-mono text-slate-400">
                    {@dashboard_metrics.by_status.finished}
                  </span>
                </div>
                <div class="flex items-center gap-3">
                  <span class="w-28 shrink-0 text-sm text-slate-300">{gettext("Pendentes")}</span>
                  <div class="flex-1 h-5 rounded bg-slate-700 overflow-hidden">
                    <div
                      class="h-full rounded bg-amber-500"
                      style={"width: #{bar_pct(@dashboard_metrics.by_status.unfinished, total)}%"}
                    >
                    </div>
                  </div>
                  <span class="w-8 text-right text-sm font-mono text-slate-400">
                    {@dashboard_metrics.by_status.unfinished}
                  </span>
                </div>
              </div>
            </div>

            <%!-- Unassigned games warning --%>
            <div
              :if={@dashboard_metrics.unassigned_count > 0}
              class="flex items-center gap-2 rounded-lg bg-amber-900/30 px-4 py-3 text-sm text-amber-300"
            >
              <.icon name="hero-exclamation-triangle-mini" class="size-4 shrink-0" />
              {ngettext(
                "%{count} jogo pendente sem mesa",
                "%{count} jogos pendentes sem mesa",
                @dashboard_metrics.unassigned_count
              )}
            </div>
          </div>

          <div class="mb-4 flex items-center justify-between">
            <h2 class="text-lg font-semibold">{gettext("Mesas")}</h2>
            <.button phx-click="open_new_table" variant="primary">
              <.icon name="hero-plus" /> {gettext("Adicionar mesa")}
            </.button>
          </div>

          <ul id="tables" phx-update="stream" class="space-y-2">
            <li
              :for={{dom_id, table} <- @streams.tables}
              id={dom_id}
              class="flex items-center justify-between rounded-lg bg-slate-800 px-4 py-3"
            >
              <div class="flex items-center gap-3">
                <span>{table.name}</span>
                <% counts =
                  Map.get(@dashboard_metrics.per_table, table.id, %{
                    finished: 0,
                    unfinished: 0
                  }) %>
                <span class="text-xs text-green-400" title={gettext("Finalizados")}>
                  <.icon name="hero-check-circle-mini" class="size-3.5 inline" />
                  {counts.finished}
                </span>
                <span class="text-xs text-amber-400" title={gettext("Pendentes")}>
                  <.icon name="hero-clock-mini" class="size-3.5 inline" />
                  {counts.unfinished}
                </span>
              </div>
              <div class="flex gap-2">
                <button
                  phx-click="open_edit_table"
                  phx-value-id={table.id}
                  class="text-slate-400 hover:text-white"
                >
                  <.icon name="hero-pencil-mini" class="size-4" />
                  <span class="sr-only">{gettext("Edit")}</span>
                </button>
                <button
                  phx-click="delete_table"
                  phx-value-id={table.id}
                  data-confirm={gettext("Are you sure?")}
                  class="text-slate-400 hover:text-red-400"
                >
                  <.icon name="hero-trash-mini" class="size-4" />
                  <span class="sr-only">{gettext("Delete")}</span>
                </button>
              </div>
            </li>
          </ul>

          <%!-- Table modal --%>
          <div :if={@table_modal != nil} class="fixed inset-0 z-50">
            <div class="absolute inset-0 bg-black/60" phx-click="close_table_modal"></div>
            <div class="relative flex h-full items-center justify-center pointer-events-none">
              <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
                <div class="mb-4 flex items-center justify-between">
                  <h2 class="text-lg font-semibold text-white">
                    {if @table_modal == :new,
                      do: gettext("Add Table"),
                      else: gettext("Edit Table")}
                  </h2>
                  <button phx-click="close_table_modal" class="text-gray-400 hover:text-white">
                    <.icon name="hero-x-mark" class="size-5" />
                  </button>
                </div>

                <.form
                  :if={@table_form}
                  for={@table_form}
                  id="table-form"
                  phx-change="validate_table"
                  phx-submit="save_table"
                >
                  <div class="space-y-4">
                    <.input field={@table_form[:name]} type="text" label={gettext("Nome")} />
                  </div>
                  <div class="mt-6 flex justify-end gap-3">
                    <.button type="button" phx-click="close_table_modal">
                      {gettext("Cancelar")}
                    </.button>
                    <.button type="submit" variant="primary">
                      {gettext("Salvar")}
                    </.button>
                  </div>
                </.form>
              </div>
            </div>
          </div>
        </div>

        <%!-- Tab: Overview --%>
        <div :if={@current_tab == "overview"} class="p-8">
          <div :if={@is_superuser} class="mb-4 flex justify-end">
            <.button phx-click="open_new_registration" variant="primary">
              <.icon name="hero-plus" /> {gettext("Nova inscrição")}
            </.button>
          </div>

          <ul
            :if={@active_category}
            id="registrations"
            phx-update="stream"
            class="space-y-4"
          >
            <li
              :for={{id, reg} <- @streams.registrations}
              id={id}
              class="flex items-center gap-2 p-4 rounded-sm bg-slate-800 shadow-xl"
            >
              <div class="min-w-0 flex-1">
                <h3 class="font-display font-black text-lg">{reg.player.name}</h3>
                <.final_standing final_standing={reg.final_standing} class="mt-2" />
                <p class="mt-2 text-sm text-sky-400">{reg.club.name}</p>
              </div>
              <div :if={@is_superuser} class="flex flex-col items-center gap-2">
                <button
                  phx-click="open_edit_registration"
                  phx-value-id={reg.id}
                  class="text-xs text-indigo-400 hover:text-indigo-300"
                >
                  <.icon name="hero-pencil-mini" />
                  <span class="sr-only">
                    {gettext("Edit")}
                  </span>
                </button>
                <button
                  phx-click="delete_registration"
                  phx-value-id={reg.id}
                  data-confirm={gettext("Are you sure?")}
                  class="text-xs text-red-400 hover:text-red-300"
                >
                  <.icon name="hero-x-circle-mini" />
                  <span class="sr-only">
                    {gettext("Remove")}
                  </span>
                </button>
              </div>
            </li>
          </ul>

          <p :if={!@active_category} class="text-gray-400 text-sm">
            {gettext("No category selected.")}
          </p>
        </div>

        <%!-- Tab: Matches --%>
        <div :if={@current_tab == "matches"} class="p-8">
          <div :if={@active_category}>
            <form :if={@match_filter_players != []} phx-change="filter_matches_by_player" class="mb-4">
              <.input
                name="player_id"
                type="select"
                label={gettext("Jogador")}
                value={@filter_player_id || ""}
                options={[{gettext("Todos jogadores"), ""}] ++ @match_filter_players}
                phx-debounce="0"
              />
            </form>

            <p :if={@all_match_cards == []} class="text-gray-400 text-sm">
              {gettext("No matches yet.")}
            </p>

            <div class="space-y-4">
              <.match_card
                :for={card <- @all_match_cards}
                card={card}
                is_superuser={@is_superuser}
              />
            </div>
          </div>

          <p :if={!@active_category} class="text-gray-400 text-sm">
            {gettext("No category selected.")}
          </p>
        </div>

        <%!-- Tab: Stage (dynamic) --%>
        <div :if={@current_stage} class="p-8">
          <div :if={@active_category}>
            <%!-- Stage header with edit/delete controls --%>
            <div :if={@is_superuser} class="mb-4 flex items-center justify-between">
              <div class="flex gap-3">
                <button
                  phx-click="open_edit_stage"
                  class="text-xs text-indigo-400 hover:text-indigo-300"
                >
                  {gettext("Editar fase")}
                </button>
                <button
                  phx-click="delete_stage"
                  data-confirm={
                    gettext("Are you sure? This will delete all groups and matches in this stage.")
                  }
                  class="text-xs text-red-400 hover:text-red-300"
                >
                  {gettext("Deletar fase")}
                </button>
              </div>
              <div class="flex gap-2">
                <.button
                  :if={@current_stage.type == "group"}
                  phx-click="open_new_group"
                  variant="primary"
                >
                  <.icon name="hero-plus" /> {gettext("Adicionar grupo")}
                </.button>
                <.button
                  :if={@current_stage.type == "bracket" and @current_stage.rounds == nil}
                  phx-click="open_bracket_setup"
                  variant="primary"
                >
                  <.icon name="hero-cog-6-tooth" /> {gettext("Configure Bracket")}
                </.button>
              </div>
            </div>

            <%!-- Groups in this stage --%>
            <div :if={@groups_with_standings != []} class="space-y-4 mb-8">
              <div
                :for={{group, standings} <- @groups_with_standings}
                id={"group-#{group.id}"}
                class="bg-slate-800 shadow-xl"
              >
                <div class="flex items-center justify-between p-4 font-display font-bold text-sm">
                  <h2 class="text-slate-100">{group.name}</h2>
                  <p :if={group.is_finished} class="text-sky-400">{gettext("Finalizado")}</p>
                  <p :if={!group.is_finished} class="text-slate-100/60">{gettext("Em andamento")}</p>
                </div>

                <div :if={standings == []} class="p-4 text-sm">
                  {gettext("No players yet.")}
                </div>

                <div :if={standings != []} class="overflow-x-auto">
                  <table class="w-full text-sm">
                    <thead>
                      <tr class="border-b border-white/10 text-left text-xs text-slate-100/60">
                        <th class="w-1 pb-2 pl-4 font-normal">#</th>
                        <th class="pb-2 px-2 font-normal">{gettext("Jogador")}</th>
                        <th class="w-1 pb-2 px-2 font-normal text-center">{gettext("V")}</th>
                        <th class="w-1 pb-2 px-2 font-normal text-center">{gettext("D")}</th>
                        <th class="w-1 pb-2 px-2 font-normal text-center">{gettext("S")}</th>
                        <th class="w-1 pb-2 pl-2 pr-4 font-normal text-center">{gettext("P")}</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={row <- standings} class="text-xs">
                        <td class="w-1 py-2 pl-4">{row.rank}</td>
                        <td class={["p-2", if(row.qualified, do: "font-bold")]}>
                          {row.registration.player.name}
                          <.icon :if={row.qualified} name="hero-check-micro" class="text-sky-400" />
                        </td>
                        <td class="w-1 p-2 text-center">{row.won}</td>
                        <td class="w-1 p-2 text-center">{row.lost}</td>
                        <td class={[
                          "w-1 p-2 text-center",
                          if(row.set_diff < 0, do: "text-slate-100/60")
                        ]}>
                          {format_diff(row.set_diff)}
                        </td>
                        <td class={[
                          "w-1 pl-2 pr-4 text-center",
                          if(row.point_diff < 0, do: "text-slate-100/60")
                        ]}>
                          {format_diff(row.point_diff)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <div
                  :if={@is_superuser}
                  class="flex items-center justify-end gap-2 p-2 border-t border-slate-100/20"
                >
                  <button
                    phx-click="open_manage_players"
                    phx-value-id={group.id}
                    class="text-xs text-gray-400 hover:text-gray-300"
                  >
                    <.icon name="hero-user-group-mini" />
                    <span class="sr-only">
                      {gettext("Jogadores")}
                    </span>
                  </button>
                  <button
                    phx-click="open_edit_group"
                    phx-value-id={group.id}
                    class="text-xs text-indigo-400 hover:text-indigo-300"
                  >
                    <.icon name="hero-pencil-mini" />
                    <span class="sr-only  ">
                      {gettext("Edit")}
                    </span>
                  </button>
                  <button
                    phx-click="delete_group"
                    phx-value-id={group.id}
                    data-confirm={gettext("Are you sure?")}
                    class="text-xs text-red-400 hover:text-red-300"
                  >
                    <.icon name="hero-x-circle-mini" />
                    <span class="sr-only  ">
                      {gettext("Delete")}
                    </span>
                  </button>
                </div>
              </div>
            </div>

            <%!-- Bracket in this stage --%>
            <div :if={@current_stage.type == "bracket" and @current_stage.rounds != nil} class="mb-8">
              <%!-- Bracket visualization --%>
              <div class="overflow-x-auto pb-6 -mx-4 px-4">
                <div class="min-w-max">
                  <%!-- Round headers --%>
                  <div class="flex">
                    <div
                      :for={round <- 1..@current_stage.rounds}
                      class="shrink-0 w-56 mb-3 h-8 flex items-end pl-3 pb-1 text-xs font-bold uppercase tracking-wider text-gray-400"
                    >
                      {round_label(round, @current_stage.rounds)}
                    </div>
                  </div>
                  <%!-- Bracket grid --%>
                  <% grid_rows = trunc(:math.pow(2, @current_stage.rounds - 1)) %>
                  <% all_matches =
                    Enum.flat_map(@stage_bracket_rounds, fn {_round, matches} -> matches end) %>
                  <div style={"display: grid; grid-template-columns: repeat(#{@current_stage.rounds}, 14rem); grid-template-rows: repeat(#{grid_rows}, auto);"}>
                    <div
                      :for={match <- all_matches}
                      id={"bracket-match-#{match.id}"}
                      class="relative flex items-center py-3"
                      style={bracket_grid_style(match)}
                    >
                      <% sorted_sets =
                        case match.sets do
                          %Ecto.Association.NotLoaded{} -> []
                          sets -> Enum.sort_by(sets, & &1.set_number)
                        end %>
                      <% sw1 =
                        Enum.count(
                          sorted_sets,
                          &(&1.winner_registration_id == match.registration1_id)
                        ) %>
                      <% sw2 =
                        Enum.count(
                          sorted_sets,
                          &(&1.winner_registration_id == match.registration2_id)
                        ) %>
                      <% p1_won =
                        not is_nil(match.winner_registration_id) and
                          match.winner_registration_id == match.registration1_id %>
                      <% p2_won =
                        not is_nil(match.winner_registration_id) and
                          match.winner_registration_id == match.registration2_id %>

                      <%!-- Left connector --%>
                      <div
                        :if={match.round > 1}
                        class="absolute left-0 top-1/2 h-0.5 w-3 bg-sky-400/60"
                      >
                      </div>

                      <%!-- Match card --%>
                      <div class="w-full pl-3 pr-6">
                        <div class="overflow-hidden rounded-sm bg-slate-800">
                          <%!-- Player 1 --%>
                          <div class={[
                            "flex items-center gap-2 px-4 py-2",
                            winner_bg(match.registration1, p1_won)
                          ]}>
                            <div class="flex-1 flex items-center gap-2 min-w-0">
                              <%!-- <span class={[
                                "min-w-0 truncate text-sm",
                                if(p1_won, do: "font-bold")
                              ]}>
                                {slot_label(match, 1)}
                              </span> --%>
                              <.label_and_player
                                registration={match.registration1}
                                label={match.slot1_label}
                                won={p1_won}
                              />
                              <.icon
                                :if={p1_won}
                                name="hero-check-mini"
                                class="shrink-0 text-sky-400"
                              />
                            </div>
                            <span
                              :if={sorted_sets != []}
                              class={[
                                "tabular-nums text-sm",
                                if(p1_won, do: "font-bold")
                              ]}
                            >
                              {sw1}
                            </span>
                          </div>
                          <%!-- Player 2 --%>
                          <div class={[
                            "flex items-center gap-2 px-4 py-2",
                            winner_bg(match.registration2, p2_won)
                          ]}>
                            <div class="flex-1 flex items-center gap-2 min-w-0">
                              <%!-- <span class={[
                                "min-w-0 truncate text-sm",
                                if(p2_won, do: "font-bold")
                              ]}>
                                {slot_label(match, 2)}
                              </span> --%>
                              <.label_and_player
                                registration={match.registration2}
                                label={match.slot2_label}
                                won={p2_won}
                              />
                              <.icon
                                :if={p2_won}
                                name="hero-check-mini"
                                class="shrink-0 text-sky-400"
                              />
                            </div>
                            <span
                              :if={sorted_sets != []}
                              class={[
                                "tabular-nums text-sm",
                                if(p2_won, do: "font-bold")
                              ]}
                            >
                              {sw2}
                            </span>
                          </div>
                          <%!-- Superuser actions --%>
                          <div class="flex items-center justify-between gap-2 border-t border-white/5 px-2.5 py-1">
                            <p class="text-xs text-slate-100/60">
                              {if match.scheduled_at,
                                do: Calendar.strftime(match.scheduled_at, "%H:%M")}
                              {if match.table, do: match.table.name}
                            </p>
                            <div :if={@is_superuser} class="flex gap-2">
                              <button
                                phx-click="open_assign_slot"
                                phx-value-id={match.id}
                                class="text-xs text-gray-500 hover:text-gray-400"
                              >
                                <.icon name="hero-user-group-mini" />
                                <span class="sr-only">
                                  {gettext("Jogadores")}
                                </span>
                              </button>
                              <button
                                phx-click="open_score_modal"
                                phx-value-id={match.id}
                                class="text-xs text-indigo-400/70 hover:text-indigo-300"
                              >
                                <.icon name="hero-numbered-list-mini" />
                                <span class="sr-only">
                                  {gettext("Resultados")}
                                </span>
                              </button>
                            </div>
                          </div>
                        </div>
                      </div>

                      <%!-- Right connector: top of pair (odd position) --%>
                      <div
                        :if={match.round < @current_stage.rounds and rem(match.position, 2) == 1}
                        class="absolute right-0 top-1/2 h-1/2 w-6 border-t-2 border-r-2 border-sky-400/60"
                      >
                      </div>

                      <%!-- Right connector: bottom of pair (even position) --%>
                      <div
                        :if={match.round < @current_stage.rounds and rem(match.position, 2) == 0}
                        class="absolute right-0 top-0 h-1/2 w-6 border-b-2 border-r-2 border-sky-400/60"
                      >
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <p
              :if={@groups_with_standings == [] and @stage_bracket_rounds == []}
              class="text-gray-400 text-sm"
            >
              {gettext("No groups or brackets in this stage yet.")}
            </p>
          </div>

          <p :if={!@active_category} class="text-gray-400 text-sm">
            {gettext("No category selected.")}
          </p>
        </div>

        <%!-- Registration modal --%>
        <div :if={@modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {if @modal == :new,
                    do: gettext("Nova Inscrição"),
                    else: gettext("Editar Inscrição")}
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
                <div class="space-y-4">
                  <.input
                    field={@form[:player_id]}
                    type="select"
                    label={gettext("Jogador")}
                    options={Enum.map(@available_players, &{&1.name, &1.id})}
                    prompt={gettext("Selecione um jogador")}
                  />
                  <.input
                    field={@form[:club_id]}
                    type="select"
                    label={gettext("Clube")}
                    options={Enum.map(@clubs, &{&1.name, &1.id})}
                    prompt={gettext("Selecione um clube")}
                  />
                  <.input
                    field={@form[:final_standing]}
                    type="number"
                    label={gettext("Colocação final")}
                    min="1"
                  />
                  <input type="hidden" name="registration[event_id]" value={@event.id} />
                  <input
                    type="hidden"
                    name="registration[category_id]"
                    value={@active_category && @active_category.id}
                  />
                </div>
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_modal">{gettext("Cancelar")}</.button>
                  <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
                </div>
              </.form>
            </div>
          </div>
        </div>

        <%!-- Manage players modal --%>
        <div :if={@players_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_players_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {gettext("Gerenciar jogadores")} — {@players_modal.name}
                </h2>
                <button phx-click="close_players_modal" class="text-gray-400 hover:text-white">
                  <span class="sr-only">{gettext("Close")}</span>
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <%!-- Current members --%>
              <div class="mb-4">
                <p class="mb-2 text-xs font-medium uppercase tracking-wide text-gray-400">
                  {gettext("Jogadores")} ({length(@players_modal.registrations)})
                </p>
                <p
                  :if={@players_modal.registrations == []}
                  class="text-sm text-gray-500"
                >
                  {gettext("No players added yet.")}
                </p>
                <ul class="space-y-1">
                  <li
                    :for={reg <- @players_modal.registrations}
                    class="flex items-center justify-between rounded px-2 py-1.5 hover:bg-white/5"
                  >
                    <span class="text-sm text-white">
                      {reg.player.name}
                      <span class="ml-1 text-xs text-gray-400">{reg.club.name}</span>
                    </span>
                    <button
                      phx-click="remove_from_group"
                      phx-value-registration_id={reg.id}
                      class="text-xs text-red-400 hover:text-red-300"
                    >
                      {gettext("Remove")}
                    </button>
                  </li>
                </ul>
              </div>

              <%!-- Add player --%>
              <% available = available_registrations(@category_registrations, @groups_with_standings) %>
              <div :if={available != []} class="mb-5">
                <label
                  for="add-player-select"
                  class="mb-2 block text-xs font-medium uppercase tracking-wide text-gray-400"
                >
                  {gettext("Add Player")}
                </label>
                <form phx-change="add_to_group">
                  <select
                    id="add-player-select"
                    name="registration_id"
                    class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  >
                    <option value="">{gettext("Selecione um jogador...")}</option>
                    <option :for={reg <- available} value={reg.id}>
                      {reg.player.name} — {reg.club.name}
                    </option>
                  </select>
                </form>
              </div>

              <%!-- Generate matches --%>
              <div class="border-t border-white/10 pt-4">
                <div class="flex items-center justify-between">
                  <div>
                    <p class="text-sm text-white">{gettext("Gerar Jogos")}</p>
                    <p class="text-xs text-gray-400">
                      {gettext("Todos contra todos. Substitui as partidas existentes.")}
                    </p>
                  </div>
                  <.button
                    phx-click="generate_matches"
                    variant="primary"
                    disabled={length(@players_modal.registrations) < 2}
                    data-confirm={
                      if @players_modal.matches != [],
                        do:
                          gettext(
                            "This will delete all existing matches for this group. Are you sure?"
                          )
                    }
                  >
                    {gettext("Gerar")}
                  </.button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Group modal --%>
        <div :if={@group_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_group_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {if @group_modal == :new,
                    do: gettext("Adicionar Grupo"),
                    else: gettext("Editar Grupo")}
                </h2>
                <button phx-click="close_group_modal" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <.form
                :if={@group_form}
                for={@group_form}
                id="group-form"
                phx-change="validate_group"
                phx-submit="save_group"
              >
                <div class="space-y-4">
                  <.input
                    field={@group_form[:name]}
                    type="text"
                    label={gettext("Nome")}
                  />
                  <.input
                    field={@group_form[:position]}
                    type="number"
                    label={gettext("Posição")}
                  />
                  <.input
                    field={@group_form[:qualifies_count]}
                    type="number"
                    label={gettext("Quantos avançam")}
                  />
                  <.input
                    field={@group_form[:is_finished]}
                    type="checkbox"
                    label={gettext("Finalizado")}
                  />
                  <input
                    type="hidden"
                    name="group[stage_id]"
                    value={@current_stage && @current_stage.id}
                  />
                </div>
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_group_modal">
                    {gettext("Cancelar")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
                </div>
              </.form>
            </div>
          </div>
        </div>

        <%!-- Scores modal --%>
        <div :if={@score_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_score_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full sm:max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <% {sm_match, _sm_context} = @score_modal %>
              <% sm_sets_by_num = Map.new(sm_match.sets, &{&1.set_number, &1}) %>
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {gettext("Editar Resultados")}
                </h2>
                <button phx-click="close_score_modal" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <form id="score-form" phx-submit="save_scores">
                <div class="grid grid-cols-[min-content_minmax(0,1fr)_min-content_minmax(0,1fr)_min-content] gap-2 w-full text-center">
                  <%!-- Column headers --%>
                  <div class="col-span-5 grid grid-cols-subgrid items-center text-xs text-slate-100/60">
                    <span>{gettext("Set")}</span>
                    <span class="truncate text-center text-slate-100">
                      <span class="font-bold text-slate-100/60">P1</span> {slot_label(sm_match, 1)}
                    </span>
                    <span class="text-center">vs</span>
                    <span class="truncate text-center text-slate-100">
                      <span class="font-bold text-slate-100/60">P2</span> {slot_label(sm_match, 2)}
                    </span>
                  </div>
                  <%!-- Set rows --%>
                  <div
                    :for={n <- 1..@score_set_count}
                    class="col-span-5 grid grid-cols-subgrid items-center"
                  >
                    <% sm_set = Map.get(sm_sets_by_num, n) %>
                    <input :if={sm_set} type="hidden" name={"sets[#{n - 1}][id]"} value={sm_set.id} />
                    <input type="hidden" name={"sets[#{n - 1}][set_number]"} value={n} />
                    <span class="text-xs">{n}</span>
                    <input
                      type="number"
                      name={"sets[#{n - 1}][score1]"}
                      value={sm_set && sm_set.score1}
                      min="0"
                      class="appearance-none rounded-sm bg-slate-800 py-3 px-4 text-base"
                    />
                    <span class="text-center text-xs text-slate-100/60">x</span>
                    <input
                      type="number"
                      name={"sets[#{n - 1}][score2]"}
                      value={sm_set && sm_set.score2}
                      min="0"
                      class="appearance-none rounded-sm bg-slate-800 py-3 px-4 text-base"
                    />
                    <button
                      :if={@score_set_count > 1}
                      type="button"
                      phx-click="remove_score_row"
                      class="text-gray-400 hover:text-red-400"
                    >
                      <.icon name="hero-x-circle-mini" class="size-5" />
                    </button>
                  </div>
                </div>
                <%!-- Add set button --%>
                <button
                  type="button"
                  phx-click="add_score_row"
                  class="mt-4 text-xs text-indigo-400 hover:text-indigo-300"
                >
                  + {gettext("Adicionar set")}
                </button>
                <%!-- Match Winner --%>
                <div class="mt-4">
                  <label class="mb-1 block text-sm font-medium text-gray-300">
                    {gettext("Vencedor da partida")}
                  </label>
                  <select
                    name="winner_registration_id"
                    class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  >
                    <option value="">{gettext("No winner yet")}</option>
                    <option
                      :if={is_struct(sm_match.registration1, Registration)}
                      value={sm_match.registration1_id}
                      selected={sm_match.winner_registration_id == sm_match.registration1_id}
                    >
                      {slot_label(sm_match, 1)}
                    </option>
                    <option
                      :if={is_struct(sm_match.registration2, Registration)}
                      value={sm_match.registration2_id}
                      selected={sm_match.winner_registration_id == sm_match.registration2_id}
                    >
                      {slot_label(sm_match, 2)}
                    </option>
                  </select>
                </div>
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_score_modal">
                    {gettext("Cancelar")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
                </div>
              </form>
            </div>
          </div>
        </div>

        <%!-- Schedule modal --%>
        <div :if={@schedule_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_schedule_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {gettext("Agendar Jogo")}
                </h2>
                <button phx-click="close_schedule_modal" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <form id="schedule-form" phx-submit="save_schedule">
                <div class="space-y-4">
                  <div>
                    <label class="mb-1 block text-sm font-medium text-gray-300">
                      {gettext("Data e hora")}
                    </label>
                    <input
                      type="datetime-local"
                      name="scheduled_at"
                      value={
                        @schedule_modal.scheduled_at &&
                          Calendar.strftime(@schedule_modal.scheduled_at, "%Y-%m-%dT%H:%M")
                      }
                      class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div>
                    <label class="mb-1 block text-sm font-medium text-gray-300">
                      {gettext("Mesa")}
                    </label>
                    <select
                      name="table_id"
                      class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    >
                      <option value="">{gettext("No table")}</option>
                      <option
                        :for={table <- @schedule_tables}
                        value={table.id}
                        selected={@schedule_modal.table_id == table.id}
                      >
                        {table.name}
                      </option>
                    </select>
                  </div>
                </div>
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_schedule_modal">
                    {gettext("Cancelar")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
                </div>
              </form>
            </div>
          </div>
        </div>

        <%!-- Bracket setup modal --%>
        <div :if={@bracket_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_bracket_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {gettext("Configure Bracket")}
                </h2>
                <button phx-click="close_bracket_modal" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <.form
                :if={@bracket_form}
                for={@bracket_form}
                id="bracket-form"
                phx-change="validate_bracket"
                phx-submit="save_bracket"
              >
                <.input
                  field={@bracket_form[:rounds]}
                  type="number"
                  label={gettext("Number of rounds (1–7)")}
                />
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_bracket_modal">
                    {gettext("Cancelar")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
                </div>
              </.form>
            </div>
          </div>
        </div>

        <%!-- Assign slot modal --%>
        <div :if={@assign_slot_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_assign_slot"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {gettext("Atribuir jogadores")}
                </h2>
                <button phx-click="close_assign_slot" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <form
                id="assign-slot-form"
                phx-submit="save_assign_slot"
              >
                <%!-- Slot 1 --%>
                <p class="mb-2 text-xs font-medium uppercase tracking-wide text-gray-400">
                  {gettext("Jogador 1")}
                </p>
                <div class="mb-5 space-y-2">
                  <label class="mb-1 block text-sm text-gray-300">{gettext("Jogador")}</label>
                  <select
                    name="slot1_registration_id"
                    class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  >
                    <option value="">{gettext("Nenhum")}</option>
                    <option
                      :for={r <- @stage_bracket_registrations}
                      value={r.id}
                      selected={@assign_slot_modal.registration1_id == r.id}
                    >
                      {r.player.name} — {r.club.name}
                    </option>
                  </select>
                  <label class="mb-1 block text-sm text-gray-300">{gettext("Rótulo")}</label>
                  <input
                    type="text"
                    name="slot1_label"
                    value={@assign_slot_modal.slot1_label}
                    placeholder={gettext("ex: 1º B, WO")}
                    class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  />
                </div>

                <%!-- Slot 2 --%>
                <p class="mb-2 text-xs font-medium uppercase tracking-wide text-gray-400">
                  {gettext("Jogador 2")}
                </p>
                <div class="mb-4 space-y-2">
                  <label class="mb-1 block text-sm text-gray-300">{gettext("Jogador")}</label>
                  <select
                    name="slot2_registration_id"
                    class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  >
                    <option value="">{gettext("Nenhum")}</option>
                    <option
                      :for={r <- @stage_bracket_registrations}
                      value={r.id}
                      selected={@assign_slot_modal.registration2_id == r.id}
                    >
                      {r.player.name} — {r.club.name}
                    </option>
                  </select>
                  <label class="mb-1 block text-sm text-gray-300">{gettext("Rótulo")}</label>
                  <input
                    type="text"
                    name="slot2_label"
                    value={@assign_slot_modal.slot2_label}
                    placeholder={gettext("ex: 2º A, WO")}
                    class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  />
                </div>

                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_assign_slot">
                    {gettext("Cancelar")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
                </div>
              </form>
            </div>
          </div>
        </div>

        <%!-- Stage modal --%>
        <div :if={@stage_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_stage_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {if @stage_modal == :new,
                    do: gettext("Adicionar Fase"),
                    else: gettext("Editar Fase")}
                </h2>
                <button phx-click="close_stage_modal" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <.form
                :if={@stage_form}
                for={@stage_form}
                id="stage-form"
                phx-change="validate_stage"
                phx-submit="save_stage"
              >
                <div class="space-y-4">
                  <.input
                    field={@stage_form[:name]}
                    type="text"
                    label={gettext("Nome")}
                  />
                  <.input
                    :if={@stage_modal == :new}
                    field={@stage_form[:type]}
                    type="select"
                    label={gettext("Type")}
                    options={[{gettext("Grupo"), "group"}, {gettext("Chave"), "bracket"}]}
                  />
                  <.input
                    field={@stage_form[:order]}
                    type="number"
                    label={gettext("Ordem")}
                  />
                  <.input
                    :if={
                      @stage_modal == :new and
                        to_string(@stage_form[:type].value) == "bracket"
                    }
                    field={@stage_form[:rounds]}
                    type="number"
                    label={gettext("Number of rounds (1–7)")}
                  />
                  <input type="hidden" name="stage[event_id]" value={@event.id} />
                  <input
                    type="hidden"
                    name="stage[category_id]"
                    value={@active_category && @active_category.id}
                  />
                </div>
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_stage_modal">
                    {gettext("Cancelar")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
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
      |> assign(:is_superuser, is_superuser)
      |> assign(:category_form, to_form(%{"category_id" => nil}, as: :category))
      |> assign(:tabs, @fixed_tabs)
      |> assign(:stages, [])
      |> assign(:current_stage, nil)
      |> assign(:stage_bracket_rounds, [])
      |> assign(:table_modal, nil)
      |> assign(:table_form, nil)
      |> assign(:modal, nil)
      |> assign(:form, nil)
      |> assign(:available_players, [])
      |> assign(:group_modal, nil)
      |> assign(:group_form, nil)
      |> assign(:players_modal, nil)
      |> assign(:category_registrations, [])
      |> assign(:groups_with_standings, [])
      |> assign(:score_modal, nil)
      |> assign(:score_set_count, 3)
      |> assign(:schedule_modal, nil)
      |> assign(:schedule_tables, [])
      |> assign(:all_match_cards, [])
      |> assign(:filter_player_id, nil)
      |> assign(:match_filter_players, [])
      |> assign(:bracket_modal, nil)
      |> assign(:bracket_form, nil)
      |> assign(:stage_bracket_registrations, [])
      |> assign(:assign_slot_modal, nil)
      |> assign(:stage_modal, nil)
      |> assign(:stage_form, nil)
      |> assign(:dashboard_metrics, %{
        per_category: [],
        by_status: %{finished: 0, unfinished: 0},
        per_table: %{},
        unassigned_count: 0
      })
      |> stream(:registrations, [])
      |> stream(:tables, [])

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
    active_category = resolve_category(event, params["category_id"])
    stages = load_stages(event, active_category)
    {tabs, tab} = resolve_tabs(stages, params["tab"], socket.assigns.is_superuser)
    current_stage = find_current_stage(tab, stages)

    filter_player_id = parse_id(params["player_id"])

    category_form =
      to_form(%{"category_id" => active_category && to_string(active_category.id)}, as: :category)

    socket =
      socket
      |> assign(:current_tab, tab)
      |> assign(:active_category, active_category)
      |> assign(:category_form, category_form)
      |> assign(:tabs, tabs)
      |> assign(:stages, stages)
      |> assign(:current_stage, current_stage)
      |> load_registrations(tab, event, active_category)
      |> load_tables(tab, event)
      |> load_stage_data(current_stage)
      |> assign(:filter_player_id, filter_player_id)
      |> assign_all_match_cards()
      |> assign_match_filter_players()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_matches_by_player", %{"player_id" => player_id}, socket) do
    %{event: event, active_category: active_category} = socket.assigns
    params = %{"tab" => "matches", "category_id" => active_category.id}
    params = if player_id != "", do: Map.put(params, "player_id", player_id), else: params
    {:noreply, push_patch(socket, to: ~p"/events/#{event}?#{params}")}
  end

  @impl true
  def handle_event("switch_category", %{"category" => %{"category_id" => id}}, socket) do
    # When switching categories, go back to overview since stage tabs will change
    {:noreply,
     push_patch(socket,
       to: ~p"/events/#{socket.assigns.event}?tab=overview&category_id=#{id}"
     )}
  end

  # ---------------------------------------------------------------------------
  # Table management
  # ---------------------------------------------------------------------------

  def handle_event("open_new_table", _params, socket) do
    form = Tables.change_table(%Table{}) |> to_form()
    {:noreply, assign(socket, table_modal: :new, table_form: form)}
  end

  def handle_event("open_edit_table", %{"id" => id}, socket) do
    table = Tables.get_table!(id)
    form = Tables.change_table(table) |> to_form()
    {:noreply, assign(socket, table_modal: {:edit, table}, table_form: form)}
  end

  def handle_event("close_table_modal", _params, socket) do
    {:noreply, assign(socket, table_modal: nil, table_form: nil)}
  end

  def handle_event("validate_table", %{"table" => attrs}, socket) do
    changeset =
      case socket.assigns.table_modal do
        {:edit, table} -> Tables.change_table(table, attrs)
        _ -> Tables.change_table(%Table{}, attrs)
      end

    {:noreply, assign(socket, table_form: changeset |> Map.put(:action, :validate) |> to_form())}
  end

  def handle_event("save_table", %{"table" => attrs}, socket) do
    scope = socket.assigns.current_scope
    event = socket.assigns.event

    result =
      case socket.assigns.table_modal do
        {:edit, table} ->
          Tables.update_table(scope, table, attrs)

        _ ->
          Tables.create_table(scope, Map.put(attrs, "event_id", event.id))
      end

    case result do
      {:ok, table} ->
        {:noreply,
         socket
         |> stream_insert(:tables, table)
         |> assign(table_modal: nil, table_form: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, table_form: to_form(changeset))}
    end
  end

  def handle_event("delete_table", %{"id" => id}, socket) do
    table = Tables.get_table!(id)
    {:ok, _} = Tables.delete_table(socket.assigns.current_scope, table)
    {:noreply, stream_delete(socket, :tables, table)}
  end

  # ---------------------------------------------------------------------------
  # Registrations
  # ---------------------------------------------------------------------------

  def handle_event("open_new_registration", _params, socket) do
    form =
      Registrations.change_registration(%Registration{})
      |> to_form()

    available_players =
      case socket.assigns.active_category do
        nil ->
          socket.assigns.players

        category ->
          registered_ids =
            Registrations.list_registered_player_ids(
              socket.assigns.event.id,
              category.id
            )

          Enum.reject(socket.assigns.players, &MapSet.member?(registered_ids, &1.id))
      end

    {:noreply, assign(socket, modal: :new, form: form, available_players: available_players)}
  end

  def handle_event("open_edit_registration", %{"id" => id}, socket) do
    reg = Registrations.get_registration!(id)

    form =
      Registrations.change_registration(reg)
      |> to_form()

    {:noreply,
     assign(socket, modal: {:edit, reg}, form: form, available_players: socket.assigns.players)}
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

  # Stage management (superuser only)

  def handle_event("open_new_stage", _params, socket) do
    next_order =
      case socket.assigns.stages do
        [] -> 1
        stages -> List.last(stages).order + 1
      end

    form =
      Matches.change_stage(%Stage{order: next_order})
      |> to_form()

    {:noreply, assign(socket, stage_modal: :new, stage_form: form)}
  end

  def handle_event("open_edit_stage", _params, socket) do
    stage = socket.assigns.current_stage

    form =
      Matches.change_stage(stage)
      |> to_form()

    {:noreply, assign(socket, stage_modal: {:edit, stage}, stage_form: form)}
  end

  def handle_event("close_stage_modal", _params, socket) do
    {:noreply, assign(socket, stage_modal: nil, stage_form: nil)}
  end

  def handle_event("validate_stage", %{"stage" => attrs}, socket) do
    form =
      case socket.assigns.stage_modal do
        {:edit, stage} -> Matches.change_stage(stage, attrs)
        _ -> Matches.change_stage(%Stage{}, attrs)
      end
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :stage_form, form)}
  end

  def handle_event("save_stage", %{"stage" => attrs}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.stage_modal do
        {:edit, stage} -> Matches.update_stage(scope, stage, attrs)
        _ -> Matches.create_stage(scope, attrs)
      end

    case result do
      {:ok, stage} ->
        {:noreply,
         socket
         |> assign(stage_modal: nil, stage_form: nil)
         |> push_patch(
           to:
             ~p"/events/#{socket.assigns.event}?tab=stage-#{stage.id}&category_id=#{socket.assigns.active_category.id}"
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, :stage_form, to_form(changeset))}
    end
  end

  def handle_event("delete_stage", _params, socket) do
    stage = socket.assigns.current_stage
    {:ok, _} = Matches.delete_stage(socket.assigns.current_scope, stage)

    {:noreply,
     push_patch(socket,
       to:
         ~p"/events/#{socket.assigns.event}?tab=overview&category_id=#{socket.assigns.active_category.id}"
     )}
  end

  # Group management (superuser only)

  def handle_event("open_new_group", _params, socket) do
    form =
      Matches.change_group(%Group{})
      |> to_form()

    {:noreply, assign(socket, group_modal: :new, group_form: form)}
  end

  def handle_event("open_edit_group", %{"id" => id}, socket) do
    group = Matches.get_group!(id)

    form =
      Matches.change_group(group)
      |> to_form()

    {:noreply, assign(socket, group_modal: {:edit, group}, group_form: form)}
  end

  def handle_event("close_group_modal", _params, socket) do
    {:noreply, assign(socket, group_modal: nil, group_form: nil)}
  end

  def handle_event("validate_group", %{"group" => attrs}, socket) do
    form =
      case socket.assigns.group_modal do
        {:edit, group} -> Matches.change_group(group, attrs)
        _ -> Matches.change_group(%Group{}, attrs)
      end
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :group_form, form)}
  end

  def handle_event("save_group", %{"group" => attrs}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.group_modal do
        {:edit, group} -> Matches.update_group(scope, group, attrs)
        _ -> Matches.create_group(scope, attrs)
      end

    case result do
      {:ok, _group} ->
        {:noreply,
         socket
         |> reload_stage_data()
         |> assign(group_modal: nil, group_form: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :group_form, to_form(changeset))}
    end
  end

  def handle_event("delete_group", %{"id" => id}, socket) do
    group = Matches.get_group!(id)
    {:ok, _} = Matches.delete_group(socket.assigns.current_scope, group)
    {:noreply, reload_stage_data(socket)}
  end

  # Group player management (superuser only)

  def handle_event("open_manage_players", %{"id" => id}, socket) do
    group = Matches.get_group_with_registrations!(id)

    category_registrations =
      Registrations.list_registrations_by_event_and_category(
        socket.assigns.event.id,
        socket.assigns.active_category
      )

    {:noreply,
     socket
     |> assign(:players_modal, group)
     |> assign(:category_registrations, category_registrations)}
  end

  def handle_event("close_players_modal", _params, socket) do
    {:noreply, assign(socket, players_modal: nil, category_registrations: [])}
  end

  def handle_event("add_to_group", %{"registration_id" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("add_to_group", %{"registration_id" => reg_id}, socket) do
    group = socket.assigns.players_modal

    Matches.add_registration_to_group(
      socket.assigns.current_scope,
      group.id,
      String.to_integer(reg_id)
    )

    updated_group = Matches.get_group_with_registrations!(group.id)

    {:noreply,
     socket
     |> assign(:players_modal, updated_group)
     |> reload_stage_data()}
  end

  def handle_event("remove_from_group", %{"registration_id" => reg_id}, socket) do
    group = socket.assigns.players_modal

    Matches.remove_registration_from_group(
      socket.assigns.current_scope,
      group.id,
      String.to_integer(reg_id)
    )

    updated_group = Matches.get_group_with_registrations!(group.id)

    {:noreply,
     socket
     |> assign(:players_modal, updated_group)
     |> reload_stage_data()}
  end

  def handle_event("generate_matches", _params, socket) do
    {:ok, _count} =
      Matches.generate_group_matches(socket.assigns.current_scope, socket.assigns.players_modal)

    {:noreply, reload_stage_data(socket)}
  end

  # Score management (superuser only)

  def handle_event("open_score_modal", %{"id" => id}, socket) do
    match_id = String.to_integer(id)

    score_modal = find_match_across_stages(match_id, socket.assigns.stages)

    score_set_count =
      case score_modal do
        {match, _} -> max(length(match.sets), 3)
        nil -> 3
      end

    {:noreply, assign(socket, score_modal: score_modal, score_set_count: score_set_count)}
  end

  def handle_event("close_score_modal", _params, socket) do
    {:noreply, assign(socket, score_modal: nil, score_set_count: 3)}
  end

  def handle_event("add_score_row", _params, socket) do
    {:noreply, update(socket, :score_set_count, &(&1 + 1))}
  end

  def handle_event("remove_score_row", _params, socket) do
    {:noreply, update(socket, :score_set_count, &max(&1 - 1, 1))}
  end

  def handle_event("save_scores", params, socket) do
    {match, _context} = socket.assigns.score_modal
    scope = socket.assigns.current_scope

    filtered_sets =
      (params["sets"] || %{})
      |> Enum.reject(fn {_, s} ->
        s["score1"] in [nil, ""] and s["score2"] in [nil, ""]
      end)
      |> Enum.map(fn {k, s} ->
        {k, Map.put(s, "winner_registration_id", infer_set_winner(s, match))}
      end)
      |> Map.new()

    match_attrs = %{
      "sets" => filtered_sets,
      "winner_registration_id" => params["winner_registration_id"]
    }

    case Matches.update_match(scope, match, match_attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_stage_data()
         |> assign(:score_modal, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save scores."))}
    end
  end

  # Schedule modal (superuser only)

  def handle_event("open_schedule_modal", %{"id" => id}, socket) do
    match_id = String.to_integer(id)

    case find_match_across_stages(match_id, socket.assigns.stages) do
      {match, _context} ->
        tables = Tables.list_tables_for_event(socket.assigns.event.id)

        {:noreply,
         assign(socket,
           schedule_modal: match,
           schedule_tables: tables
         )}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("close_schedule_modal", _params, socket) do
    {:noreply, assign(socket, schedule_modal: nil)}
  end

  def handle_event("save_schedule", params, socket) do
    match = socket.assigns.schedule_modal
    scope = socket.assigns.current_scope

    table_id =
      case params["table_id"] do
        "" -> nil
        id -> id
      end

    scheduled_at =
      case params["scheduled_at"] do
        "" -> nil
        dt -> dt
      end

    attrs = %{"scheduled_at" => scheduled_at, "table_id" => table_id}

    case Matches.update_match(scope, match, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_stage_data()
         |> assign(:schedule_modal, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save schedule."))}
    end
  end

  # Bracket management (superuser only)

  def handle_event("open_bracket_setup", _params, socket) do
    stage = socket.assigns.current_stage

    form =
      stage
      |> Matches.change_stage(%{})
      |> to_form(as: "bracket")

    {:noreply, assign(socket, bracket_modal: :setup, bracket_form: form)}
  end

  def handle_event("close_bracket_modal", _params, socket) do
    {:noreply, assign(socket, bracket_modal: nil, bracket_form: nil)}
  end

  def handle_event("validate_bracket", %{"bracket" => attrs}, socket) do
    stage = socket.assigns.current_stage

    form =
      stage
      |> Matches.change_stage(attrs)
      |> Map.put(:action, :validate)
      |> to_form(as: "bracket")

    {:noreply, assign(socket, :bracket_form, form)}
  end

  def handle_event("save_bracket", %{"bracket" => attrs}, socket) do
    stage = socket.assigns.current_stage
    scope = socket.assigns.current_scope
    rounds = attrs["rounds"]

    result =
      Matches.update_stage(scope, stage, %{rounds: rounds})
      |> case do
        {:ok, updated_stage} ->
          Matches.reconfigure_stage_bracket(scope, updated_stage, rounds)

        error ->
          error
      end

    case result do
      {:ok, _stage} ->
        {:noreply,
         socket
         |> reload_stage_data()
         |> assign(bracket_modal: nil, bracket_form: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :bracket_form, to_form(changeset, as: "bracket"))}
    end
  end

  def handle_event("open_assign_slot", %{"id" => id}, socket) do
    match_id = String.to_integer(id)
    stage = socket.assigns.current_stage

    match = Enum.find(stage.matches, &(&1.id == match_id))

    registrations =
      Registrations.list_registrations_by_event_and_category(
        socket.assigns.event.id,
        socket.assigns.active_category
      )

    {:noreply,
     socket
     |> assign(:assign_slot_modal, match)
     |> assign(:stage_bracket_registrations, registrations)}
  end

  def handle_event("close_assign_slot", _params, socket) do
    {:noreply, assign(socket, assign_slot_modal: nil, stage_bracket_registrations: [])}
  end

  def handle_event("save_assign_slot", params, socket) do
    match = socket.assigns.assign_slot_modal
    scope = socket.assigns.current_scope

    label_attrs = %{
      slot1_label: params["slot1_label"],
      slot2_label: params["slot2_label"]
    }

    reg1_id = parse_registration_id(params["slot1_registration_id"])
    reg2_id = parse_registration_id(params["slot2_registration_id"])

    result =
      with {:ok, _} <- Matches.update_match(scope, match, label_attrs),
           fresh_match = Matches.get_match!(match.id),
           {:ok, _} <- Matches.assign_bracket_slot_direct(scope, fresh_match, 1, reg1_id),
           fresh_match2 = Matches.get_match!(match.id),
           {:ok, _} <- Matches.assign_bracket_slot_direct(scope, fresh_match2, 2, reg2_id) do
        :done
      else
        {:error, _} -> :error
      end

    case result do
      :error ->
        {:noreply, put_flash(socket, :error, gettext("Could not assign slot."))}

      _ ->
        {:noreply,
         socket
         |> reload_stage_data()
         |> assign(assign_slot_modal: nil, stage_bracket_registrations: [])}
    end
  end

  # Private helpers

  defp resolve_category(event, category_id_param) do
    case Integer.parse(category_id_param || "") do
      {id, ""} -> Enum.find(event.categories, &(&1.id == id))
      _ -> List.first(event.categories)
    end
  end

  defp load_stages(_event, nil), do: []

  defp load_stages(event, category) do
    Matches.list_stages_for_event_and_category(event.id, category.id)
  end

  defp resolve_tabs(stages, tab_param, is_superuser) do
    stage_tabs = Enum.map(stages, fn s -> "stage-#{s.id}" end)

    tabs =
      if is_superuser,
        do: @fixed_tabs ++ stage_tabs,
        else: Enum.reject(@fixed_tabs, &(&1 == "management")) ++ stage_tabs

    tab = if tab_param in tabs, do: tab_param, else: "overview"
    {tabs, tab}
  end

  defp find_current_stage("stage-" <> id_str, stages) do
    case Integer.parse(id_str) do
      {stage_id, ""} -> Enum.find(stages, &(&1.id == stage_id))
      _ -> nil
    end
  end

  defp find_current_stage(_tab, _stages), do: nil

  defp load_registrations(socket, "overview", event, active_category)
       when not is_nil(active_category) do
    stream(
      socket,
      :registrations,
      Registrations.list_registrations_by_event_and_category(event.id, active_category),
      reset: true
    )
  end

  defp load_registrations(socket, _tab, _event, _active_category), do: socket

  defp load_tables(socket, "management", event) do
    {table_counts, unassigned} = Matches.count_matches_per_table(event.id)

    socket
    |> stream(:tables, Tables.list_tables_for_event(event.id), reset: true)
    |> assign(:dashboard_metrics, %{
      per_category: Matches.count_matches_per_category(event.id),
      by_status: Matches.count_matches_by_status(event.id),
      per_table: table_counts,
      unassigned_count: unassigned
    })
  end

  defp load_tables(socket, _tab, _event), do: socket

  defp parse_registration_id(value) when value in ["", nil], do: nil
  defp parse_registration_id(value), do: String.to_integer(value)

  defp load_stage_data(socket, nil) do
    socket
    |> assign(:groups_with_standings, [])
    |> assign(:stage_bracket_rounds, [])
  end

  defp load_stage_data(socket, stage) do
    # Groups with standings
    groups_with_standings =
      Enum.map(stage.groups, fn g -> {g, Matches.compute_group_standings(g)} end)

    # Bracket rounds (for bracket-type stages)
    bracket_rounds =
      if stage.type == "bracket" and stage.rounds do
        compute_bracket_rounds(stage)
      else
        []
      end

    socket
    |> assign(:groups_with_standings, groups_with_standings)
    |> assign(:stage_bracket_rounds, bracket_rounds)
  end

  defp reload_stage_data(socket) do
    event = socket.assigns.event
    active_category = socket.assigns.active_category

    if active_category do
      stages = Matches.list_stages_for_event_and_category(event.id, active_category.id)
      current_stage_id = socket.assigns.current_stage && socket.assigns.current_stage.id
      current_stage = Enum.find(stages, &(&1.id == current_stage_id))

      socket
      |> assign(:stages, stages)
      |> load_stage_data(current_stage)
      |> assign(:current_stage, current_stage)
      |> assign_all_match_cards()
    else
      socket
    end
  end

  defp assign_all_match_cards(%{assigns: %{current_tab: "matches"}} = socket) do
    cards =
      socket.assigns.stages
      |> Enum.flat_map(&stage_match_cards/1)
      |> filter_match_cards(socket.assigns.filter_player_id)
      |> Enum.sort_by(fn card -> card.sort_key end)

    assign(socket, :all_match_cards, cards)
  end

  defp assign_all_match_cards(socket), do: socket

  defp filter_match_cards(cards, nil), do: cards

  defp filter_match_cards(cards, player_id) do
    Enum.filter(cards, &(&1.p1_player_id == player_id or &1.p2_player_id == player_id))
  end

  defp stage_match_cards(stage) do
    group_cards =
      Enum.flat_map(stage.groups, fn group ->
        ctx = %{
          label: "#{group.name}",
          source: :group,
          stage_order: stage.order,
          group_position: group.position
        }

        Enum.map(group.matches, &prepare_match_card(&1, ctx))
      end)

    bracket_cards =
      if stage.type == "bracket" and stage.rounds do
        Enum.flat_map(compute_bracket_rounds(stage), fn {round, matches} ->
          ctx = %{
            label: "#{stage.name} - #{round_label(round, stage.rounds)}",
            source: :bracket,
            stage_order: stage.order
          }

          Enum.map(matches, &prepare_match_card(&1, ctx))
        end)
      else
        []
      end

    group_cards ++ bracket_cards
  end

  defp compute_bracket_rounds(stage) do
    stage.matches
    |> Enum.group_by(& &1.round)
    |> Enum.sort_by(fn {round, _} -> round end)
    |> Enum.map(fn {round, matches} -> {round, Enum.sort_by(matches, & &1.position)} end)
  end

  defp find_match_across_stages(match_id, stages) do
    Enum.find_value(stages, fn stage ->
      find_match_in_groups(match_id, stage.groups) ||
        find_match_in_stage(match_id, stage)
    end)
  end

  defp find_match_in_groups(match_id, groups) do
    Enum.find_value(groups, fn g ->
      case Enum.find(g.matches, &(&1.id == match_id)) do
        nil -> nil
        match -> {match, g}
      end
    end)
  end

  defp find_match_in_stage(match_id, stage) do
    if stage && stage.type == "bracket" do
      case Enum.find(stage.matches, &(&1.id == match_id)) do
        nil -> nil
        match -> {match, :bracket}
      end
    else
      nil
    end
  end

  defp prepare_match_card(match, %{label: label, source: source} = ctx) do
    sorted_sets = sort_sets(match.sets)

    sw1 = Enum.count(sorted_sets, &(&1.winner_registration_id == match.registration1_id))
    sw2 = Enum.count(sorted_sets, &(&1.winner_registration_id == match.registration2_id))

    sort_key = match_sort_key(match, ctx)

    %{
      id: match.id,
      label: label,
      source: source,
      sort_key: sort_key,
      scheduled_at: match.scheduled_at,
      table: match.table,
      has_sets: sorted_sets != [],
      p1_scores: Enum.map(sorted_sets, &format_set_score(&1.score1)),
      p2_scores: Enum.map(sorted_sets, &format_set_score(&1.score2)),
      sw1: sw1,
      sw2: sw2,
      p1_won:
        match.winner_registration_id == match.registration1_id and
          not is_nil(match.winner_registration_id),
      p2_won:
        match.winner_registration_id == match.registration2_id and
          not is_nil(match.winner_registration_id),
      p1_name: card_player_name(match, 1, source),
      p2_name: card_player_name(match, 2, source),
      p1_player_id: card_player_id(match.registration1),
      p2_player_id: card_player_id(match.registration2)
    }
  end

  defp match_sort_key(match, %{source: :group} = ctx) do
    {ctx.stage_order, 0, ctx.group_position, match.scheduled_position, match.id}
  end

  defp match_sort_key(match, %{source: :bracket} = ctx) do
    {ctx.stage_order, 1, match.round, match.position, match.id}
  end

  defp sort_sets(%Ecto.Association.NotLoaded{}), do: []
  defp sort_sets(sets), do: Enum.sort_by(sets, & &1.set_number)

  defp format_set_score(nil), do: "–"
  defp format_set_score(score), do: to_string(score)

  defp card_player_name(match, 1, :group), do: match_player_name(match.registration1)
  defp card_player_name(match, 2, :group), do: match_player_name(match.registration2)
  defp card_player_name(match, slot, :bracket), do: slot_label(match, slot)

  defp card_player_id(%{player: %{id: id}}), do: id
  defp card_player_id(_), do: nil

  defp assign_match_filter_players(%{assigns: %{current_tab: "matches", stages: stages}} = socket) do
    players =
      stages
      |> Enum.flat_map(&extract_players_from_stage/1)
      |> Enum.uniq_by(&elem(&1, 1))
      |> Enum.sort_by(&elem(&1, 0))

    assign(socket, :match_filter_players, players)
  end

  defp assign_match_filter_players(socket), do: socket

  defp extract_players_from_stage(stage) do
    group_players =
      Enum.flat_map(stage.groups, fn group ->
        Enum.flat_map(group.matches, &extract_players_from_match/1)
      end)

    bracket_players = Enum.flat_map(stage.matches, &extract_players_from_match/1)

    group_players ++ bracket_players
  end

  defp extract_players_from_match(match) do
    [match.registration1, match.registration2]
    |> Enum.filter(&match?(%{player: %{id: _}}, &1))
    |> Enum.map(&{&1.player.name, &1.player.id})
  end

  defp match_card(assigns) do
    ~H"""
    <div id={"match-#{@card.id}"} class="rounded-sm bg-slate-800 shadow-xl">
      <%!-- Card header --%>
      <div class="flex items-center gap-4 p-4 pb-2 border-b border-slate-100/20">
        <p class="flex-1 font-display font-bold text-sm text-slate-100/60">{@card.label}</p>
        <p :if={@card.scheduled_at || @card.table} class="text-xs">
          {if @card.scheduled_at, do: Calendar.strftime(@card.scheduled_at, "%H:%M")}
          {if @card.table, do: @card.table.name}
        </p>
        <div :if={@card.has_sets} class="font-display font-bold text-sm text-cyan-400">
          {@card.sw1} — {@card.sw2}
        </div>
      </div>

      <%!-- Player rows --%>
      <div class="space-y-2 p-4 pt-3">
        <div class="flex items-center gap-2">
          <div class="flex-1 flex items-center gap-2">
            <span class={[
              "min-w-0 truncate text-sm",
              if(@card.p1_won, do: "font-bold")
            ]}>
              {@card.p1_name}
            </span>
            <.icon :if={@card.p1_won} name="hero-check-micro" class="shrink-0 text-sky-400" />
          </div>
          <span
            :if={@card.has_sets}
            class="w-5 shrink-0 text-center text-sm font-bold text-white"
          >
            {@card.sw1}
          </span>
          <div class="flex gap-1">
            <span
              :for={score <- @card.p1_scores}
              class="w-7 text-center text-xs tabular-nums text-gray-400"
            >
              {score}
            </span>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <div class="flex-1 flex items-center gap-2">
            <span class={[
              "min-w-0 truncate text-sm",
              if(@card.p2_won, do: "font-bold")
            ]}>
              {@card.p2_name}
            </span>
            <.icon :if={@card.p2_won} name="hero-check-micro" class="shrink-0 text-sky-400" />
          </div>
          <span
            :if={@card.has_sets}
            class="w-5 shrink-0 text-center text-sm font-bold text-white"
          >
            {@card.sw2}
          </span>
          <div class="flex gap-1">
            <span
              :for={score <- @card.p2_scores}
              class="w-7 text-center text-xs tabular-nums text-gray-400"
            >
              {score}
            </span>
          </div>
        </div>
      </div>

      <%!-- Superuser actions --%>
      <div
        :if={@is_superuser}
        class="flex justify-end gap-3 border-t border-white/10 px-4 py-2"
      >
        <button
          phx-click="open_schedule_modal"
          phx-value-id={@card.id}
          class="text-xs text-indigo-400 hover:text-indigo-300"
        >
          {gettext("Agenda")}
        </button>
        <button
          phx-click="open_score_modal"
          phx-value-id={@card.id}
          class="text-xs text-indigo-400 hover:text-indigo-300"
        >
          {gettext("Resultados")}
        </button>
      </div>
    </div>
    """
  end

  attr :registration, :any, required: true
  attr :label, :any, required: true
  attr :won, :boolean, required: true

  defp label_and_player(assigns) do
    name =
      case assigns.registration do
        %Registration{} = registration -> registration.player.name
        _ -> nil
      end

    label =
      if assigns.label in [nil, ""], do: nil, else: assigns.label

    assigns =
      assigns
      |> assign(:name, name)
      |> assign(:label, label)

    ~H"""
    <span :if={@name && @label} class="shrink-0 text-xs text-slate-100/60 whitespace-nowrap">
      {@label}
    </span>
    <span class={["truncate text-sm", if(@won, do: "font-bold")]}>
      {@name || @label || gettext("TBD")}
    </span>
    """
  end

  defp available_registrations(category_registrations, groups_with_standings) do
    taken_ids =
      MapSet.new(
        Enum.flat_map(groups_with_standings, fn {g, _} -> g.registrations end),
        & &1.id
      )

    Enum.reject(category_registrations, &MapSet.member?(taken_ids, &1.id))
  end

  defp superuser?(%{current_scope: %{user: %{role: "superuser"}}}), do: true
  defp superuser?(_), do: false

  defp tab_label("management", _stages), do: gettext("Gestão")
  defp tab_label("overview", _stages), do: gettext("Visão geral")
  defp tab_label("matches", _stages), do: gettext("Jogos")

  defp tab_label("stage-" <> id_str, stages) do
    case Integer.parse(id_str) do
      {stage_id, ""} ->
        case Enum.find(stages, &(&1.id == stage_id)) do
          nil -> "?"
          stage -> stage.name
        end

      _ ->
        "?"
    end
  end

  defp tab_label(_tab, _stages), do: "?"

  defp tab_params(_current_tab, active_category, tab) do
    base = %{"tab" => tab}
    category_id = active_category && active_category.id
    if category_id, do: Map.put(base, "category_id", category_id), else: base
  end

  defp format_diff(n) when n > 0, do: "+#{n}"
  defp format_diff(n), do: to_string(n)

  defp round_label(round, total_rounds) do
    rounds_from_end = total_rounds - round

    case rounds_from_end do
      0 -> gettext("Final")
      1 -> gettext("Semis")
      2 -> gettext("Quartas")
      3 -> gettext("Oitavas")
      4 -> gettext("R32")
      5 -> gettext("R64")
      6 -> gettext("R128")
      _ -> gettext("R%{n}", n: round)
    end
  end

  defp infer_set_winner(set_params, match) do
    with {s1, ""} <- Integer.parse(set_params["score1"] || ""),
         {s2, ""} <- Integer.parse(set_params["score2"] || "") do
      cond do
        s1 > s2 -> match.registration1_id
        s2 > s1 -> match.registration2_id
        true -> nil
      end
    else
      _ -> nil
    end
  end

  defp slot_label(match, n) do
    case n do
      1 -> {match.registration1, match.slot1_label}
      2 -> {match.registration2, match.slot2_label}
    end
    |> case do
      {%Registration{} = registration, _} -> registration.player.name
      {_, label} when label not in [nil, ""] -> label
      _ -> gettext("TBD")
    end
  end

  # Height in px for one bracket slot at the given round (doubles each round).
  defp bracket_grid_style(match) do
    span = trunc(:math.pow(2, match.round - 1))
    start = (match.position - 1) * span + 1
    "grid-column: #{match.round}; grid-row: #{start} / span #{span};"
  end

  defp match_player_name(%{player: %{name: name}}), do: name
  defp match_player_name(_), do: gettext("TBD")

  defp parse_id(nil), do: nil

  defp parse_id(str) do
    case Integer.parse(str) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp bar_pct(_value, 0), do: 0
  defp bar_pct(value, max), do: round(value / max * 100)

  defp max_count(rows), do: Enum.reduce(rows, 0, fn row, acc -> max(row.count, acc) end)

  defp winner_bg(%Registration{final_standing: 1}, _won), do: "bg-yellow-400/20"
  defp winner_bg(%Registration{final_standing: 2}, _won), do: "bg-slate-400/20"
  defp winner_bg(_registration, true), do: "bg-sky-400/10"
  defp winner_bg(_registration, _won), do: nil

  attr :final_standing, :any, required: true
  attr :class, :any, default: nil

  defp final_standing(%{final_standing: nil} = assigns), do: ~H""

  defp final_standing(assigns) do
    {text, bg_class} =
      case assigns.final_standing do
        1 -> {gettext("Campeão 🥇"), "bg-yellow-400/20"}
        2 -> {gettext("Vice-campeão 🥈"), "bg-slate-400/20"}
        3 -> {gettext("3º lugar 🥉"), "bg-amber-800/10"}
        n -> {gettext("%{position}º lugar", position: n), "bg-sky-400/20"}
      end

    assigns =
      assigns
      |> assign(:text, text)
      |> assign(:bg_class, bg_class)

    ~H"""
    <div class={@class}>
      <p class={["inline-block px-2 py-1 rounded-sm text-sm", @bg_class]}>
        {@text}
      </p>
    </div>
    """
  end
end
