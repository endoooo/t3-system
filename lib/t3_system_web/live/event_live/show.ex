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
        <div class="px-4 pt-10 pb-6 sm:px-8">
          <h1 class="font-display text-3xl font-black tracking-tight">{@event.name}</h1>
          <div class="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-sm text-fg-muted">
            <span :if={@event.datetime} class="flex items-center gap-1.5">
              <.icon name="hero-calendar-mini" />
              {Calendar.strftime(@event.datetime, "%d/%m/%Y %H:%M")}
            </span>
            <span :if={@event.address} class="flex items-center gap-1.5">
              <.icon name="hero-map-pin-mini" />
              {@event.address}
            </span>
          </div>

          <%!-- Category selector --%>
          <.form
            :if={@event.categories != []}
            for={@category_form}
            id="category-form"
            phx-change="switch_category"
            class="mt-6 sm:max-w-xs"
          >
            <.input
              field={@category_form[:category_id]}
              type="select"
              label={gettext("Category")}
              sr_only
              options={Enum.map(@event.categories, &{&1.name, &1.id})}
            />
          </.form>
        </div>

        <%!-- Tab nav --%>
        <.tabs
          label={gettext("Tabs")}
          class="pl-4 after:w-4 after:shrink-0 after:content-[''] sm:pl-8 sm:after:w-8"
        >
          <:tab
            :for={tab <- @tabs}
            patch={~p"/events/#{@event}?#{tab_params(@current_tab, @active_category, tab)}"}
            active={tab == @current_tab}
          >
            {tab_label(tab, @stages)}
          </:tab>
          <%!-- Add stage button (superuser only) --%>
          <button
            :if={@is_superuser and @active_category}
            phx-click="open_new_stage"
            class="border-b-2 border-transparent py-3 text-fg-subtle transition-colors hover:text-fg"
          >
            <.icon name="hero-plus-mini" class="size-5" />
            <span class="sr-only">{gettext("Adicionar Fase")}</span>
          </button>
        </.tabs>

        <%!-- Tab: Management --%>
        <div
          :if={@current_tab == "management" and @is_superuser and not @schedule_view}
          class="space-y-8 px-4 py-8 sm:px-8"
        >
          <%!-- Dashboard Metrics --%>
          <div class="grid gap-4 sm:grid-cols-2">
            <%!-- Games per category --%>
            <.card>
              <h3 class="mb-4 text-sm font-semibold text-fg-muted">
                {gettext("Jogos por categoria")}
              </h3>
              <p :if={@dashboard_metrics.per_category == []} class="text-sm text-fg-subtle">
                {gettext("Nenhum jogo registrado.")}
              </p>
              <div class="space-y-3">
                <.meter
                  :for={row <- @dashboard_metrics.per_category}
                  label={row.category_name}
                  value={row.count}
                  max={max_count(@dashboard_metrics.per_category)}
                />
              </div>
            </.card>

            <%!-- Finished vs unfinished --%>
            <.card>
              <h3 class="mb-4 text-sm font-semibold text-fg-muted">
                {gettext("Jogos finalizados vs. pendentes")}
              </h3>
              <% total =
                @dashboard_metrics.by_status.finished + @dashboard_metrics.by_status.unfinished %>
              <p :if={total == 0} class="text-sm text-fg-subtle">
                {gettext("Nenhum jogo registrado.")}
              </p>
              <div :if={total > 0} class="space-y-3">
                <.meter
                  label={gettext("Finalizados")}
                  value={@dashboard_metrics.by_status.finished}
                  max={total}
                  tone="success"
                />
                <.meter
                  label={gettext("Pendentes")}
                  value={@dashboard_metrics.by_status.unfinished}
                  max={total}
                  tone="warning"
                />
              </div>
            </.card>
          </div>

          <%!-- Unassigned games warning --%>
          <.alert :if={@dashboard_metrics.unassigned_count > 0} tone="warning">
            {ngettext(
              "%{count} jogo pendente sem mesa",
              "%{count} jogos pendentes sem mesa",
              @dashboard_metrics.unassigned_count
            )}
          </.alert>

          <section class="space-y-4">
            <.section_title>
              {gettext("Mesas")}
              <:actions>
                <.button patch={
                  ~p"/events/#{@event}?#{Map.put(tab_params(@current_tab, @active_category, "management"), "view", "schedule")}"
                }>
                  <.icon name="hero-calendar-days" /> {gettext("Agenda")}
                </.button>
                <.button phx-click="open_new_table" variant="primary">
                  <.icon name="hero-plus" /> {gettext("Adicionar mesa")}
                </.button>
              </:actions>
            </.section_title>

            <ul id="tables" phx-update="stream" class="space-y-2">
              <li id="tables-empty" class="hidden only:block">
                <.empty_state icon="hero-table-cells">
                  {gettext("Nenhuma mesa cadastrada.")}
                </.empty_state>
              </li>
              <.card
                :for={{dom_id, table} <- @streams.tables}
                id={dom_id}
                tag="li"
                padded={false}
                class="flex items-center justify-between gap-3 py-1 pr-1 pl-4"
              >
                <div class="flex min-w-0 items-center gap-3">
                  <span class="truncate font-medium">{table.name}</span>
                  <% counts =
                    Map.get(@dashboard_metrics.per_table, table.id, %{
                      finished: 0,
                      unfinished: 0
                    }) %>
                  <.badge tone="success" title={gettext("Finalizados")}>
                    <.icon name="hero-check-circle-micro" class="size-3.5" />
                    {counts.finished}
                  </.badge>
                  <.badge tone="warning" title={gettext("Pendentes")}>
                    <.icon name="hero-clock-micro" class="size-3.5" />
                    {counts.unfinished}
                  </.badge>
                </div>
                <div class="flex">
                  <.icon_button
                    name="hero-pencil-mini"
                    sr_label={gettext("Edit")}
                    phx-click="open_edit_table"
                    phx-value-id={table.id}
                  />
                  <.icon_button
                    name="hero-trash-mini"
                    sr_label={gettext("Delete")}
                    tone="danger"
                    phx-click="delete_table"
                    phx-value-id={table.id}
                    data-confirm={gettext("Are you sure?")}
                  />
                </div>
              </.card>
            </ul>
          </section>

          <%!-- Table modal --%>
          <.modal
            :if={@table_modal != nil}
            id="table-modal"
            title={if @table_modal == :new, do: gettext("Add Table"), else: gettext("Edit Table")}
            on_close="close_table_modal"
          >
            <.form
              :if={@table_form}
              for={@table_form}
              id="table-form"
              phx-change="validate_table"
              phx-submit="save_table"
              class="space-y-6"
            >
              <.input field={@table_form[:name]} type="text" label={gettext("Nome")} />
              <.modal_actions on_cancel="close_table_modal" />
            </.form>
          </.modal>
        </div>

        <%!-- Tab: Overview --%>
        <div :if={@current_tab == "overview"} class="space-y-4 px-4 py-8 sm:px-8">
          <div :if={@is_superuser} class="flex justify-end">
            <.button phx-click="open_new_registration" variant="primary">
              <.icon name="hero-plus" /> {gettext("Nova inscrição")}
            </.button>
          </div>

          <ul
            :if={@active_category}
            id="registrations"
            phx-update="stream"
            class="grid gap-3 sm:grid-cols-2"
          >
            <li id="registrations-empty" class="hidden only:block sm:col-span-2">
              <.empty_state icon="hero-user-group">
                {gettext("Nenhuma inscrição ainda.")}
              </.empty_state>
            </li>
            <.card
              :for={{id, reg} <- @streams.registrations}
              id={id}
              tag="li"
              class="flex items-start gap-2"
            >
              <div class="min-w-0 flex-1 space-y-2">
                <h3 class="font-display text-lg font-black">{reg.player.name}</h3>
                <.final_standing final_standing={reg.final_standing} />
                <p class="text-sm text-primary">{reg.club.name}</p>
              </div>
              <div :if={@is_superuser} class="-mt-1.5 -mr-1.5 flex">
                <.icon_button
                  name="hero-pencil-mini"
                  sr_label={gettext("Edit")}
                  phx-click="open_edit_registration"
                  phx-value-id={reg.id}
                />
                <.icon_button
                  name="hero-x-circle-mini"
                  sr_label={gettext("Remove")}
                  tone="danger"
                  phx-click="delete_registration"
                  phx-value-id={reg.id}
                  data-confirm={gettext("Are you sure?")}
                />
              </div>
            </.card>
          </ul>

          <.empty_state :if={!@active_category}>
            {gettext("No category selected.")}
          </.empty_state>
        </div>

        <%!-- Tab: Matches --%>
        <div :if={@current_tab == "matches"} class="px-4 py-8 sm:px-8">
          <div :if={@active_category} class="space-y-6">
            <form
              :if={@match_filter_players != []}
              phx-change="filter_matches_by_player"
              class="sm:max-w-xs"
            >
              <.input
                name="player_id"
                type="select"
                label={gettext("Jogador")}
                value={@filter_player_id || ""}
                options={[{gettext("Filtrar por atleta"), ""}] ++ @match_filter_players}
                phx-debounce="0"
                sr_only
              />
            </form>

            <.empty_state :if={@all_match_cards == []} icon="hero-trophy">
              {gettext("No matches yet.")}
            </.empty_state>

            <div class="grid gap-3 sm:grid-cols-2">
              <.match_card
                :for={card <- @all_match_cards}
                card={card}
                is_superuser={@is_superuser}
              />
            </div>
          </div>

          <.empty_state :if={!@active_category}>
            {gettext("No category selected.")}
          </.empty_state>
        </div>

        <%!-- Tab: Stage (dynamic) --%>
        <div :if={@current_stage} class="px-4 py-8 sm:px-8">
          <div :if={@active_category} class="space-y-6">
            <%!-- Stage header with edit/delete controls --%>
            <div :if={@is_superuser} class="flex flex-wrap items-center justify-between gap-3">
              <div class="-ml-3 flex gap-1">
                <.button variant="ghost" size="sm" phx-click="open_edit_stage">
                  <.icon name="hero-pencil-micro" class="size-3.5" /> {gettext("Editar fase")}
                </.button>
                <.button
                  variant="danger"
                  size="sm"
                  phx-click="delete_stage"
                  data-confirm={
                    gettext("Are you sure? This will delete all groups and matches in this stage.")
                  }
                >
                  <.icon name="hero-trash-micro" class="size-3.5" /> {gettext("Deletar fase")}
                </.button>
              </div>
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

            <%!-- Groups in this stage --%>
            <div :if={@groups_with_standings != []} class="grid gap-4 md:grid-cols-2">
              <.card
                :for={{group, standings} <- @groups_with_standings}
                id={"group-#{group.id}"}
                padded={false}
                class="overflow-hidden"
              >
                <div class="flex items-center justify-between gap-3 p-4">
                  <h2 class="font-display text-sm font-bold">{group.name}</h2>
                  <.badge :if={group.is_finished} tone="primary">{gettext("Finalizado")}</.badge>
                  <.badge :if={!group.is_finished}>{gettext("Em andamento")}</.badge>
                </div>

                <p :if={standings == []} class="px-4 pb-4 text-sm text-fg-muted">
                  {gettext("No players yet.")}
                </p>

                <div :if={standings != []} class="overflow-x-auto">
                  <table class="w-full text-sm">
                    <thead>
                      <tr class="border-b border-border text-left text-xs text-fg-muted">
                        <th class="w-1 pb-2 pl-4 font-normal">#</th>
                        <th class="px-2 pb-2 font-normal">{gettext("Jogador")}</th>
                        <th class="w-1 px-2 pb-2 text-center font-normal">{gettext("V")}</th>
                        <th class="w-1 px-2 pb-2 text-center font-normal">{gettext("D")}</th>
                        <th class="w-1 px-2 pb-2 text-center font-normal">{gettext("S")}</th>
                        <th class="w-1 pr-4 pb-2 pl-2 text-center font-normal">{gettext("P")}</th>
                      </tr>
                    </thead>
                    <tbody class="tabular-nums">
                      <tr :for={row <- standings} class="text-xs even:bg-fg/[0.03]">
                        <td class="w-1 py-2.5 pl-4 text-fg-muted">{row.rank}</td>
                        <td class={["px-2 py-2.5", row.qualified && "font-bold"]}>
                          {row.registration.player.name}
                          <.icon :if={row.qualified} name="hero-check-micro" class="text-primary" />
                        </td>
                        <td class="w-1 px-2 py-2.5 text-center">{row.won}</td>
                        <td class="w-1 px-2 py-2.5 text-center">{row.lost}</td>
                        <td class={[
                          "w-1 px-2 py-2.5 text-center",
                          row.set_diff < 0 && "text-fg-muted"
                        ]}>
                          {format_diff(row.set_diff)}
                        </td>
                        <td class={[
                          "w-1 py-2.5 pr-4 pl-2 text-center",
                          row.point_diff < 0 && "text-fg-muted"
                        ]}>
                          {format_diff(row.point_diff)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <div
                  :if={@is_superuser}
                  class="flex items-center justify-end border-t border-border px-1"
                >
                  <.icon_button
                    name="hero-user-group-mini"
                    sr_label={gettext("Jogadores")}
                    phx-click="open_manage_players"
                    phx-value-id={group.id}
                  />
                  <.icon_button
                    name="hero-pencil-mini"
                    sr_label={gettext("Edit")}
                    phx-click="open_edit_group"
                    phx-value-id={group.id}
                  />
                  <.icon_button
                    name="hero-x-circle-mini"
                    sr_label={gettext("Delete")}
                    tone="danger"
                    phx-click="delete_group"
                    phx-value-id={group.id}
                    data-confirm={gettext("Are you sure?")}
                  />
                </div>
              </.card>
            </div>

            <%!-- Bracket in this stage --%>
            <div :if={@current_stage.type == "bracket" and @current_stage.rounds != nil}>
              <%!-- Bracket visualization --%>
              <div class="-mx-4 overflow-x-auto px-4 pb-6">
                <div class="min-w-max">
                  <%!-- Round headers --%>
                  <div class="flex">
                    <div
                      :for={round <- 1..@current_stage.rounds}
                      class="mb-3 flex h-8 w-56 shrink-0 items-end pb-1 pl-3 text-xs font-bold tracking-wider text-fg-muted uppercase"
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
                      <% sorted_sets = sort_sets(match.sets) %>
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
                        class="absolute top-1/2 left-0 h-0.5 w-3 bg-primary/60"
                      >
                      </div>

                      <%!-- Match card --%>
                      <div class="w-full pr-6 pl-3">
                        <.card padded={false} class="overflow-hidden">
                          <.bracket_slot
                            registration={match.registration1}
                            label={match.slot1_label}
                            won={p1_won}
                            is_bye={match.is_bye}
                            set_wins={sorted_sets != [] && sw1}
                          />
                          <.bracket_slot
                            registration={match.registration2}
                            label={match.slot2_label}
                            won={p2_won}
                            is_bye={match.is_bye}
                            set_wins={sorted_sets != [] && sw2}
                          />
                          <div
                            :if={@is_superuser || match.scheduled_at || match.table}
                            class="flex min-h-7 items-center justify-between gap-2 border-t border-border px-2.5"
                          >
                            <p class="text-xs text-fg-muted">
                              {if match.scheduled_at,
                                do: Calendar.strftime(match.scheduled_at, "%H:%M")}
                              {if match.table, do: match.table.name}
                            </p>
                            <%!-- Superuser actions --%>
                            <div :if={@is_superuser} class="-mr-1.5 flex">
                              <.icon_button
                                name="hero-user-group-mini"
                                sr_label={gettext("Jogadores")}
                                phx-click="open_assign_slot"
                                phx-value-id={match.id}
                              />
                              <.icon_button
                                name="hero-numbered-list-mini"
                                sr_label={gettext("Resultados")}
                                tone="primary"
                                phx-click="open_score_modal"
                                phx-value-id={match.id}
                              />
                            </div>
                          </div>
                        </.card>
                      </div>

                      <%!-- Right connector: top of pair (odd position) --%>
                      <div
                        :if={match.round < @current_stage.rounds and rem(match.position, 2) == 1}
                        class="absolute top-1/2 right-0 h-1/2 w-6 border-t-2 border-r-2 border-primary/60"
                      >
                      </div>

                      <%!-- Right connector: bottom of pair (even position) --%>
                      <div
                        :if={match.round < @current_stage.rounds and rem(match.position, 2) == 0}
                        class="absolute top-0 right-0 h-1/2 w-6 border-r-2 border-b-2 border-primary/60"
                      >
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <.empty_state
              :if={@groups_with_standings == [] and @stage_bracket_rounds == []}
              icon="hero-squares-2x2"
            >
              {gettext("No groups or brackets in this stage yet.")}
            </.empty_state>
          </div>

          <.empty_state :if={!@active_category}>
            {gettext("No category selected.")}
          </.empty_state>
        </div>

        <%!-- Registration modal --%>
        <.modal
          :if={@modal != nil}
          id="registration-modal"
          title={if @modal == :new, do: gettext("Nova Inscrição"), else: gettext("Editar Inscrição")}
          on_close="close_modal"
        >
          <.form
            :if={@form}
            for={@form}
            id="registration-form"
            phx-change="validate"
            phx-submit="save_registration"
            class="space-y-6"
          >
            <div class="space-y-5">
              <div
                id={"player-combobox-#{@combobox_key}"}
                phx-hook=".PlayerCombobox"
                phx-update="ignore"
              >
                <.label for="player-autocomplete">{gettext("Jogador")}</.label>
                <el-autocomplete class="relative block">
                  <input
                    id="player-autocomplete"
                    type="text"
                    placeholder={gettext("Buscar jogador...")}
                    value={@player_search}
                    phx-mounted={JS.focus()}
                    class={[field_class(), "pr-12"]}
                  />
                  <button
                    type="button"
                    class="absolute inset-y-0 right-0 flex items-center rounded-r-control px-3"
                  >
                    <.icon name="hero-chevron-up-down" class="size-5 text-fg-muted" />
                  </button>
                  <el-options
                    anchor="bottom end"
                    popover
                    class="max-h-60 w-(--input-width) overflow-auto rounded-control bg-surface py-1 text-base shadow-lg outline -outline-offset-1 outline-border transition-discrete [--anchor-gap:--spacing(1)] data-leave:transition data-leave:duration-100 data-leave:ease-in data-closed:data-leave:opacity-0 sm:text-sm"
                  >
                    <el-option
                      :for={player <- @available_players}
                      value={player.name}
                      data-player-id={player.id}
                      class="block truncate px-4 py-2 text-fg select-none aria-selected:bg-primary aria-selected:text-on-primary"
                    >
                      {player.name}
                    </el-option>
                  </el-options>
                </el-autocomplete>
              </div>
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
            <.modal_actions on_cancel="close_modal" />
          </.form>
        </.modal>

        <%!-- Manage players modal --%>
        <.modal
          :if={@players_modal != nil}
          id="players-modal"
          title={gettext("Gerenciar jogadores") <> " — " <> @players_modal.name}
          on_close="close_players_modal"
        >
          <div class="space-y-6">
            <%!-- Current members --%>
            <section>
              <h3 class="mb-2 text-xs font-medium tracking-wide text-fg-muted uppercase">
                {gettext("Jogadores")} ({length(@players_modal.registrations)})
              </h3>
              <p :if={@players_modal.registrations == []} class="text-sm text-fg-subtle">
                {gettext("No players added yet.")}
              </p>
              <ul class="-mx-2 space-y-0.5">
                <li
                  :for={reg <- @players_modal.registrations}
                  class="flex items-center justify-between gap-3 rounded-control py-1 pr-1 pl-2 hover:bg-fg/5"
                >
                  <span class="min-w-0 truncate text-sm">
                    {reg.player.name}
                    <span class="ml-1 text-xs text-fg-muted">{reg.club.name}</span>
                  </span>
                  <.button
                    variant="danger"
                    size="sm"
                    phx-click="remove_from_group"
                    phx-value-registration_id={reg.id}
                  >
                    {gettext("Remove")}
                  </.button>
                </li>
              </ul>
            </section>

            <%!-- Add player --%>
            <% available = available_registrations(@category_registrations, @groups_with_standings) %>
            <form :if={available != []} phx-change="add_to_group">
              <.input
                id="add-player-select"
                name="registration_id"
                type="select"
                label={gettext("Add Player")}
                prompt={gettext("Selecione um jogador...")}
                value=""
                options={Enum.map(available, &{"#{&1.player.name} — #{&1.club.name}", &1.id})}
              />
            </form>

            <%!-- Generate matches --%>
            <div class="flex items-center justify-between gap-4 border-t border-border pt-5">
              <div>
                <p class="text-sm font-medium">{gettext("Gerar Jogos")}</p>
                <p class="text-xs text-fg-muted">
                  {gettext("Todos contra todos. Substitui as partidas existentes.")}
                </p>
              </div>
              <.button
                phx-click="generate_matches"
                variant="primary"
                disabled={length(@players_modal.registrations) < 2}
                data-confirm={
                  if @players_modal.matches != [],
                    do: gettext("This will delete all existing matches for this group. Are you sure?")
                }
              >
                {gettext("Gerar")}
              </.button>
            </div>
          </div>
        </.modal>

        <%!-- Group modal --%>
        <.modal
          :if={@group_modal != nil}
          id="group-modal"
          title={
            if @group_modal == :new, do: gettext("Adicionar Grupo"), else: gettext("Editar Grupo")
          }
          on_close="close_group_modal"
        >
          <.form
            :if={@group_form}
            for={@group_form}
            id="group-form"
            phx-change="validate_group"
            phx-submit="save_group"
            class="space-y-6"
          >
            <div class="space-y-5">
              <.input field={@group_form[:name]} type="text" label={gettext("Nome")} />
              <div class="grid grid-cols-2 gap-4">
                <.input field={@group_form[:position]} type="number" label={gettext("Posição")} />
                <.input
                  field={@group_form[:qualifies_count]}
                  type="number"
                  label={gettext("Quantos avançam")}
                />
              </div>
              <.input field={@group_form[:is_finished]} type="toggle" label={gettext("Finalizado")} />
              <input
                type="hidden"
                name="group[stage_id]"
                value={@current_stage && @current_stage.id}
              />
            </div>
            <.modal_actions on_cancel="close_group_modal" />
          </.form>
        </.modal>

        <%!-- Scores modal --%>
        <.modal
          :if={@score_modal != nil}
          id="score-modal"
          title={gettext("Editar Resultados")}
          on_close="close_score_modal"
        >
          <% {sm_match, _sm_context} = @score_modal %>
          <% sm_sets_by_num = Map.new(sm_match.sets, &{&1.set_number, &1}) %>
          <form id="score-form" phx-submit="save_scores" class="space-y-6">
            <div>
              <div class="grid w-full grid-cols-[min-content_minmax(0,1fr)_min-content_minmax(0,1fr)_2.5rem] items-center gap-2 text-center">
                <%!-- Column headers --%>
                <div class="col-span-5 grid grid-cols-subgrid items-center text-xs text-fg-muted">
                  <span>{gettext("Set")}</span>
                  <span class="truncate text-fg">
                    <span class="font-bold text-fg-muted">P1</span> {slot_label(sm_match, 1)}
                  </span>
                  <span>vs</span>
                  <span class="truncate text-fg">
                    <span class="font-bold text-fg-muted">P2</span> {slot_label(sm_match, 2)}
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
                  <span class="text-xs text-fg-muted">{n}</span>
                  <.input
                    id={"score-#{n}-1"}
                    type="number"
                    name={"sets[#{n - 1}][score1]"}
                    value={sm_set && sm_set.score1}
                    label={gettext("Set %{n}, P1", n: n)}
                    sr_only
                    min="0"
                    class="text-center"
                  />
                  <span class="text-xs text-fg-muted">x</span>
                  <.input
                    id={"score-#{n}-2"}
                    type="number"
                    name={"sets[#{n - 1}][score2]"}
                    value={sm_set && sm_set.score2}
                    label={gettext("Set %{n}, P2", n: n)}
                    sr_only
                    min="0"
                    class="text-center"
                  />
                  <.icon_button
                    :if={@score_set_count > 1}
                    name="hero-x-circle-mini"
                    sr_label={gettext("Remove set")}
                    tone="danger"
                    phx-click="remove_score_row"
                  />
                </div>
              </div>
              <%!-- Add set button --%>
              <.button
                type="button"
                variant="ghost"
                size="sm"
                phx-click="add_score_row"
                class="mt-3 -ml-3"
              >
                <.icon name="hero-plus-micro" class="size-3.5" /> {gettext("Adicionar set")}
              </.button>
            </div>
            <%!-- Match Winner --%>
            <.input
              id="winner-registration-id"
              type="select"
              name="winner_registration_id"
              label={gettext("Vencedor da partida")}
              prompt={gettext("No winner yet")}
              options={winner_options(sm_match)}
              value={sm_match.winner_registration_id}
            />
            <.modal_actions on_cancel="close_score_modal" />
          </form>
        </.modal>

        <%!-- Schedule modal --%>
        <.modal
          :if={@schedule_modal != nil}
          id="schedule-modal"
          title={gettext("Editar horário")}
          on_close="close_schedule_modal"
        >
          <form id="schedule-form" phx-submit="save_schedule" class="space-y-6">
            <.input
              id="schedule-scheduled-at"
              type="datetime-local"
              name="scheduled_at"
              label={gettext("Data e hora")}
              value={
                @schedule_modal.scheduled_at &&
                  Calendar.strftime(@schedule_modal.scheduled_at, "%Y-%m-%dT%H:%M")
              }
            />
            <.modal_actions on_cancel="close_schedule_modal" />
          </form>
        </.modal>

        <%!-- Bracket setup modal --%>
        <.modal
          :if={@bracket_modal != nil}
          id="bracket-modal"
          title={gettext("Configure Bracket")}
          on_close="close_bracket_modal"
        >
          <.form
            :if={@bracket_form}
            for={@bracket_form}
            id="bracket-form"
            phx-change="validate_bracket"
            phx-submit="save_bracket"
            class="space-y-6"
          >
            <.input
              field={@bracket_form[:rounds]}
              type="number"
              label={gettext("Number of rounds (1–7)")}
            />
            <.modal_actions on_cancel="close_bracket_modal" />
          </.form>
        </.modal>

        <%!-- Assign slot modal --%>
        <.modal
          :if={@assign_slot_modal != nil}
          id="assign-slot-modal"
          title={gettext("Atribuir jogadores")}
          on_close="close_assign_slot"
        >
          <form id="assign-slot-form" phx-submit="save_assign_slot" class="space-y-6">
            <fieldset
              :for={
                {slot, legend, placeholder, registration_id, slot_label} <- [
                  {1, gettext("Jogador 1"), gettext("ex: 1º B, WO"),
                   @assign_slot_modal.registration1_id, @assign_slot_modal.slot1_label},
                  {2, gettext("Jogador 2"), gettext("ex: 2º A, WO"),
                   @assign_slot_modal.registration2_id, @assign_slot_modal.slot2_label}
                ]
              }
              class="space-y-3"
            >
              <legend class="mb-3 text-xs font-medium tracking-wide text-fg-muted uppercase">
                {legend}
              </legend>
              <.input
                id={"slot#{slot}-registration-id"}
                type="select"
                name={"slot#{slot}_registration_id"}
                label={gettext("Jogador")}
                prompt={gettext("Nenhum")}
                options={
                  Enum.map(
                    @stage_bracket_registrations,
                    &{"#{&1.player.name} — #{&1.club.name}", &1.id}
                  )
                }
                value={registration_id}
              />
              <.input
                id={"slot#{slot}-label"}
                type="text"
                name={"slot#{slot}_label"}
                label={gettext("Rótulo")}
                value={slot_label}
                placeholder={placeholder}
              />
            </fieldset>

            <.input
              id="is-bye-toggle"
              type="toggle"
              name="is_bye"
              value={@assign_slot_modal.is_bye}
              label={gettext("Bye")}
            />

            <.modal_actions on_cancel="close_assign_slot" />
          </form>
        </.modal>

        <%!-- Stage modal --%>
        <.modal
          :if={@stage_modal != nil}
          id="stage-modal"
          title={if @stage_modal == :new, do: gettext("Adicionar Fase"), else: gettext("Editar Fase")}
          on_close="close_stage_modal"
        >
          <.form
            :if={@stage_form}
            for={@stage_form}
            id="stage-form"
            phx-change="validate_stage"
            phx-submit="save_stage"
            class="space-y-6"
          >
            <div class="space-y-5">
              <.input field={@stage_form[:name]} type="text" label={gettext("Nome")} />
              <.input
                :if={@stage_modal == :new}
                field={@stage_form[:type]}
                type="select"
                label={gettext("Type")}
                options={[{gettext("Grupo"), "group"}, {gettext("Chave"), "bracket"}]}
              />
              <.input field={@stage_form[:order]} type="number" label={gettext("Ordem")} />
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
            <.modal_actions on_cancel="close_stage_modal" />
          </.form>
        </.modal>
      </div>
      <%!-- Management: schedule view (the board uses the full screen width) --%>
      <div :if={@current_tab == "management" and @is_superuser and @schedule_view} class="pb-8">
        <div class="mx-auto max-w-4xl space-y-6 px-4 py-8 sm:px-8">
          <.section_title>
            {gettext("Agenda")}
            <:actions>
              <.button
                variant="ghost"
                size="sm"
                patch={
                  ~p"/events/#{@event}?#{tab_params(@current_tab, @active_category, "management")}"
                }
              >
                <.icon name="hero-arrow-left-micro" class="size-3.5" /> {gettext("Voltar")}
              </.button>
            </:actions>
          </.section_title>

          <div class="flex flex-wrap items-end gap-4">
            <.form
              for={@duration_form}
              id="match-duration-form"
              phx-change="update_match_duration"
              phx-submit="update_match_duration"
              class="w-48"
            >
              <.input
                field={@duration_form[:match_duration_minutes]}
                type="number"
                min="1"
                label={gettext("Duração dos jogos (min)")}
                phx-debounce="500"
              />
            </.form>

            <button
              id="unscheduled-indicator"
              type="button"
              phx-click="open_unscheduled_modal"
              class={[
                "flex items-center gap-2 rounded-card px-4 py-2.5 text-sm font-medium inset-ring transition-colors",
                if(@unscheduled_matches == [],
                  do: "text-fg-muted inset-ring-border hover:bg-fg/5",
                  else: "bg-warning/10 text-warning inset-ring-warning/30 hover:bg-warning/15"
                )
              ]}
            >
              <.icon name="hero-inbox-stack-mini" />
              {ngettext(
                "%{count} partida sem mesa",
                "%{count} partidas sem mesa",
                length(@unscheduled_matches)
              )}
            </button>
          </div>

          <p class="text-sm text-fg-muted">
            {gettext(
              "O primeiro jogo de cada mesa começa no horário do evento e os seguintes a cada intervalo de duração. Arraste os jogos para reordenar ou trocar de mesa. Jogos finalizados ficam fixos."
            )}
          </p>

          <.empty_state :if={@table_schedules == []} icon="hero-table-cells">
            {gettext("Cadastre mesas na aba Gestão para montar a agenda.")}
          </.empty_state>
        </div>

        <div
          :if={@table_schedules != []}
          id="schedule-board"
          phx-hook=".ScheduleBoard"
          class="grid auto-cols-[minmax(16rem,1fr)] grid-flow-col items-start gap-4 overflow-x-auto px-4 pb-4 sm:px-8"
        >
          <section
            :for={%{table: table, finished: finished, pending: pending} <- @table_schedules}
            id={"schedule-table-#{table.id}"}
            class="space-y-2"
          >
            <h3 class="flex h-7 items-center gap-2 text-sm font-semibold">
              <span class="truncate">{table.name}</span>
              <.badge>{length(pending)}</.badge>
            </h3>
            <ul :if={finished != []} class="space-y-2">
              <.schedule_match_card :for={match <- finished} match={match} frozen />
            </ul>
            <ul
              id={"schedule-list-table-#{table.id}"}
              data-schedule-list
              data-table-id={table.id}
              class="min-h-16 space-y-2 rounded-card border border-dashed border-border p-2"
            >
              <li class="hidden p-2 text-center text-xs text-fg-subtle only:block">
                {gettext("Nenhum jogo na fila.")}
              </li>
              <.schedule_match_card :for={match <- pending} match={match} />
            </ul>
            <.button
              variant="ghost"
              size="sm"
              class="w-full"
              phx-click="open_unscheduled_modal"
              phx-value-table_id={table.id}
            >
              <.icon name="hero-plus-micro" class="size-3.5" /> {gettext("Adicionar jogo")}
            </.button>
          </section>
        </div>

        <%!-- Unscheduled matches modal --%>
        <.modal
          :if={@unscheduled_modal}
          id="unscheduled-modal"
          title={unscheduled_modal_title(@unscheduled_modal)}
          on_close="close_unscheduled_modal"
          class="max-w-lg"
        >
          <% matches = filter_unscheduled(@unscheduled_matches, @unscheduled_category_id) %>
          <form
            :if={length(@event.categories) > 1}
            id="unscheduled-filter"
            phx-change="filter_unscheduled"
            class="mb-4"
          >
            <.input
              id="unscheduled-category"
              name="category_id"
              type="select"
              label={gettext("Categoria")}
              sr_only
              prompt={gettext("Todas as categorias")}
              options={Enum.map(@event.categories, &{&1.name, &1.id})}
              value={@unscheduled_category_id}
            />
          </form>
          <p :if={matches == []} class="text-sm text-fg-subtle">
            {gettext("Nenhuma partida sem mesa.")}
          </p>
          <ul :if={matches != []} class="-mx-2 max-h-[60vh] space-y-0.5 overflow-y-auto">
            <li
              :for={match <- matches}
              id={"unscheduled-match-#{match.id}"}
              class="flex items-center gap-3 rounded-control py-1.5 pr-1 pl-2 hover:bg-fg/5"
            >
              <div class="min-w-0 flex-1">
                <p class="truncate text-xs text-fg-muted">{schedule_match_label(match)}</p>
                <p class="truncate text-sm">
                  {slot_label(match, 1)} <span class="text-fg-muted">vs</span> {slot_label(match, 2)}
                </p>
              </div>
              <.button
                :if={match?({:table, _}, @unscheduled_modal)}
                size="sm"
                phx-click="add_match_to_table"
                phx-value-match_id={match.id}
                phx-value-table_id={elem(@unscheduled_modal, 1).id}
              >
                {gettext("Adicionar")}
              </.button>
              <form
                :if={@unscheduled_modal == :any}
                id={"assign-table-form-#{match.id}"}
                phx-change="add_match_to_table"
                class="w-36 shrink-0"
              >
                <input type="hidden" name="match_id" value={match.id} />
                <.input
                  id={"assign-table-#{match.id}"}
                  name="table_id"
                  type="select"
                  label={gettext("Mesa")}
                  sr_only
                  prompt={gettext("Mesa...")}
                  value=""
                  options={Enum.map(@table_schedules, &{&1.table.name, &1.table.id})}
                />
              </form>
            </li>
          </ul>
        </.modal>
      </div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".ScheduleBoard">
        import Sortable from "sortablejs"

        export default {
          mounted() {
            this.initLists()
          },
          updated() {
            this.initLists()
          },
          initLists() {
            for (const list of this.el.querySelectorAll("[data-schedule-list]")) {
              if (Sortable.get(list)) continue

              Sortable.create(list, {
                group: "schedule",
                draggable: "[data-match-id]",
                filter: "button",
                preventOnFilter: false,
                animation: 150,
                ghostClass: "opacity-40",
                onEnd: (e) => this.pushMove(e)
              })
            }
          },
          pushMove(e) {
            if (e.from === e.to && e.oldIndex === e.newIndex) return

            const lists = [...new Set([e.from, e.to])]

            this.pushEvent("reorder_schedule", {
              lists: lists.map((list) => ({
                table_id: list.dataset.tableId,
                match_ids: [...list.querySelectorAll(":scope > [data-match-id]")].map(
                  (item) => item.dataset.matchId
                )
              }))
            })
          }
        }
      </script>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".PlayerCombobox">
        export default {
          mounted() {
            const autocomplete = this.el.querySelector("el-autocomplete")
            const input = autocomplete.querySelector("input[type=text]")
            let lastPushed = input.value

            // Keep the search input's events away from the form's phx-change. Otherwise
            // they trigger a form patch that closes the club select's dropdown as it opens.
            for (const type of ["input", "change"]) {
              this.el.addEventListener(type, (e) => e.stopPropagation())
            }

            input.addEventListener("change", () => {
              // The browser fires "change" again on blur; skip it if nothing changed
              if (input.value === lastPushed) return
              lastPushed = input.value

              const option = autocomplete.querySelector(`el-option[value="${CSS.escape(input.value)}"]`)
              const playerId = option ? option.dataset.playerId : ""
              this.pushEvent("select_player", { id: playerId, name: input.value })
            })
          }
        }
      </script>
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
      |> assign(:player_search, "")
      |> assign(:combobox_key, 0)
      |> assign(:group_modal, nil)
      |> assign(:group_form, nil)
      |> assign(:players_modal, nil)
      |> assign(:category_registrations, [])
      |> assign(:groups_with_standings, [])
      |> assign(:score_modal, nil)
      |> assign(:score_set_count, 3)
      |> assign(:schedule_modal, nil)
      |> assign(:table_schedules, [])
      |> assign(:unscheduled_matches, [])
      |> assign(:duration_form, nil)
      |> assign(:schedule_view, false)
      |> assign(:unscheduled_modal, nil)
      |> assign(:unscheduled_category_id, nil)
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
      |> assign(:schedule_view, tab == "management" and params["view"] == "schedule")
      |> assign(:active_category, active_category)
      |> assign(:category_form, category_form)
      |> assign(:tabs, tabs)
      |> assign(:stages, stages)
      |> assign(:current_stage, current_stage)
      |> load_registrations(tab, event, active_category)
      |> load_tables(tab, event)
      |> assign_schedule()
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

    {:noreply,
     assign(socket,
       modal: :new,
       form: form,
       available_players: unregistered_players(socket),
       player_search: "",
       selected_player_id: nil
     )}
  end

  def handle_event("open_edit_registration", %{"id" => id}, socket) do
    reg = Registrations.get_registration!(id)

    form =
      Registrations.change_registration(reg)
      |> to_form()

    player_name =
      Enum.find_value(socket.assigns.players, "", fn p ->
        if p.id == reg.player_id, do: p.name
      end)

    {:noreply,
     assign(socket,
       modal: {:edit, reg},
       form: form,
       available_players: socket.assigns.players,
       player_search: player_name,
       selected_player_id: reg.player_id
     )}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil, form: nil)}
  end

  def handle_event("select_player", %{"id" => id, "name" => name}, socket) do
    # Merge into the current params so other fields (e.g. club) are preserved
    attrs = Map.put(socket.assigns.form.params, "player_id", id)

    form =
      case socket.assigns.modal do
        {:edit, reg} -> Registrations.change_registration(reg, attrs)
        _ -> Registrations.change_registration(%Registration{}, attrs)
      end
      |> to_form()

    {:noreply, assign(socket, player_search: name, selected_player_id: id, form: form)}
  end

  def handle_event("validate", %{"registration" => attrs}, socket) do
    attrs = ensure_player_id(attrs, socket)

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
    attrs = ensure_player_id(attrs, socket)
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.modal do
        {:edit, reg} -> Registrations.update_registration(scope, reg, attrs)
        _ -> Registrations.create_registration(scope, attrs)
      end

    case {socket.assigns.modal, result} do
      {:new, {:ok, reg}} ->
        reg = Registrations.get_registration!(reg.id)
        socket = stream_insert(socket, :registrations, reg)

        # Keep the modal open for the next registration, preserving the selected club
        form =
          Registrations.change_registration(%Registration{}, %{"club_id" => attrs["club_id"]})
          |> to_form()

        {:noreply,
         socket
         |> assign(
           form: form,
           available_players: unregistered_players(socket),
           player_search: "",
           selected_player_id: nil
         )
         |> update(:combobox_key, &(&1 + 1))
         |> put_flash(:info, gettext("Inscrição de %{name} adicionada.", name: reg.player.name))}

      {_, {:ok, reg}} ->
        reg = Registrations.get_registration!(reg.id)

        {:noreply,
         socket
         |> stream_insert(:registrations, reg)
         |> assign(modal: nil, form: nil)}

      {_, {:error, changeset}} ->
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
    {:ok, count} =
      Matches.generate_group_matches(socket.assigns.current_scope, socket.assigns.players_modal)

    {:noreply,
     socket
     |> put_flash(
       :info,
       ngettext("%{count} match generated", "%{count} matches generated", count, count: count)
     )
     |> reload_stage_data()}
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
        # Finishing (or reopening) a match changes which times are frozen on its table
        if match.table_id,
          do: Matches.recalculate_table_schedule(scope, socket.assigns.event, match.table_id)

        {:noreply,
         socket
         |> reload_stage_data()
         |> assign(:score_modal, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save scores."))}
    end
  end

  # Schedule (superuser only)

  def handle_event("update_match_duration", %{"event" => attrs}, socket) do
    case Matches.update_match_duration(socket.assigns.current_scope, socket.assigns.event, attrs) do
      {:ok, event} ->
        {:noreply, socket |> assign(:event, event) |> assign_schedule()}

      {:error, changeset} ->
        {:noreply, assign(socket, :duration_form, to_form(changeset, action: :validate))}
    end
  end

  def handle_event("reorder_schedule", %{"lists" => lists}, socket) do
    lists =
      Enum.map(lists, fn list ->
        %{
          table_id: parse_id(list["table_id"]),
          match_ids: list["match_ids"] |> Enum.map(&parse_id/1) |> Enum.reject(&is_nil/1)
        }
      end)

    :ok =
      Matches.update_table_schedule(socket.assigns.current_scope, socket.assigns.event, lists)

    {:noreply, assign_schedule(socket)}
  end

  def handle_event("unschedule_match", %{"id" => id}, socket) do
    :ok =
      Matches.update_table_schedule(socket.assigns.current_scope, socket.assigns.event, [
        %{table_id: nil, match_ids: [String.to_integer(id)]}
      ])

    {:noreply, assign_schedule(socket)}
  end

  def handle_event("open_unscheduled_modal", params, socket) do
    table_id = parse_id(params["table_id"])

    modal =
      case Enum.find(socket.assigns.table_schedules, &(&1.table.id == table_id)) do
        %{table: table} -> {:table, table}
        nil -> :any
      end

    {:noreply, assign(socket, unscheduled_modal: modal, unscheduled_category_id: nil)}
  end

  def handle_event("close_unscheduled_modal", _params, socket) do
    {:noreply, assign(socket, :unscheduled_modal, nil)}
  end

  def handle_event("filter_unscheduled", %{"category_id" => category_id}, socket) do
    {:noreply, assign(socket, :unscheduled_category_id, parse_id(category_id))}
  end

  def handle_event("add_match_to_table", %{"table_id" => ""}, socket), do: {:noreply, socket}

  def handle_event(
        "add_match_to_table",
        %{"match_id" => match_id, "table_id" => table_id},
        socket
      ) do
    %{current_scope: scope, event: event} = socket.assigns

    case Matches.add_match_to_table(scope, event, parse_id(match_id), parse_id(table_id)) do
      :ok ->
        {:noreply, assign_schedule(socket)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Não foi possível adicionar a partida."))
         |> assign_schedule()}
    end
  end

  def handle_event("open_schedule_modal", %{"id" => id}, socket) do
    match = Matches.get_match!(id)

    if match.event_id == socket.assigns.event.id do
      {:noreply, assign(socket, :schedule_modal, match)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_schedule_modal", _params, socket) do
    {:noreply, assign(socket, schedule_modal: nil)}
  end

  def handle_event("save_schedule", params, socket) do
    match = socket.assigns.schedule_modal
    %{current_scope: scope, event: event} = socket.assigns

    scheduled_at =
      case params["scheduled_at"] do
        "" -> nil
        dt -> dt
      end

    case Matches.update_match(scope, match, %{"scheduled_at" => scheduled_at}) do
      {:ok, _} ->
        # A finished match's time anchors the pending matches that follow it
        if match.table_id, do: Matches.recalculate_table_schedule(scope, event, match.table_id)

        {:noreply,
         socket
         |> assign_schedule()
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
      slot2_label: params["slot2_label"],
      is_bye: params["is_bye"] == "true"
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

  defp assign_schedule(%{assigns: %{schedule_view: true, is_superuser: true}} = socket) do
    event = socket.assigns.event

    socket
    |> assign(:table_schedules, Matches.list_table_schedules(event.id))
    |> assign(:unscheduled_matches, Matches.list_unscheduled_matches(event.id))
    |> assign(:duration_form, to_form(Matches.change_match_duration(event)))
  end

  defp assign_schedule(socket), do: socket

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
    %{event: event, active_category: active_category} = socket.assigns

    stages =
      Matches.list_stages_for_event_and_category(event.id, active_category.id, exclude_byes: true)

    cards =
      stages
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

  attr :card, :map, required: true
  attr :is_superuser, :boolean, required: true

  defp match_card(assigns) do
    ~H"""
    <.card id={"match-#{@card.id}"} padded={false}>
      <%!-- Card header --%>
      <div class="flex items-center gap-4 border-b border-border px-4 py-2.5">
        <p class="min-w-0 flex-1 truncate font-display text-sm font-bold text-fg-muted">
          {@card.label}
        </p>
        <p :if={@card.scheduled_at || @card.table} class="text-xs text-fg-muted">
          {if @card.scheduled_at, do: Calendar.strftime(@card.scheduled_at, "%H:%M")}
          {if @card.table, do: @card.table.name}
        </p>
        <div :if={@card.has_sets} class="font-display text-sm font-bold text-primary tabular-nums">
          {@card.sw1} — {@card.sw2}
        </div>
      </div>

      <%!-- Player rows --%>
      <div class="space-y-2 p-4 pt-3">
        <.match_card_row
          name={@card.p1_name}
          won={@card.p1_won}
          has_sets={@card.has_sets}
          set_wins={@card.sw1}
          scores={@card.p1_scores}
        />
        <.match_card_row
          name={@card.p2_name}
          won={@card.p2_won}
          has_sets={@card.has_sets}
          set_wins={@card.sw2}
          scores={@card.p2_scores}
        />
      </div>

      <%!-- Superuser actions --%>
      <div :if={@is_superuser} class="flex justify-end gap-1 border-t border-border px-2 py-1.5">
        <.button
          variant="ghost"
          size="sm"
          phx-click="open_score_modal"
          phx-value-id={@card.id}
        >
          {gettext("Resultados")}
        </.button>
      </div>
    </.card>
    """
  end

  attr :match, :map, required: true
  attr :frozen, :boolean, default: false, doc: "finished matches can't be dragged"

  defp schedule_match_card(assigns) do
    ~H"""
    <li
      id={"schedule-match-#{@match.id}"}
      data-match-id={!@frozen && @match.id}
      class={[
        "rounded-control bg-surface px-3 py-2 inset-ring inset-ring-border",
        if(@frozen, do: "opacity-60", else: "cursor-grab active:cursor-grabbing")
      ]}
    >
      <div class="flex items-center gap-2 text-xs text-fg-muted">
        <span class="min-w-0 flex-1 truncate">{schedule_match_label(@match)}</span>
        <span :if={@match.scheduled_at} class="font-semibold text-fg tabular-nums">
          {Calendar.strftime(@match.scheduled_at, "%H:%M")}
        </span>
        <.icon_button
          :if={@frozen}
          name="hero-pencil-micro"
          sr_label={gettext("Editar horário")}
          class="-my-1.5 -mr-2"
          phx-click="open_schedule_modal"
          phx-value-id={@match.id}
        />
        <.icon_button
          :if={!@frozen}
          name="hero-x-mark-micro"
          sr_label={gettext("Remover da mesa")}
          class="-my-1.5 -mr-2"
          phx-click="unschedule_match"
          phx-value-id={@match.id}
        />
      </div>
      <p
        :for={slot <- [1, 2]}
        class={[
          "truncate text-sm",
          (@frozen and @match.winner_registration_id == slot_registration_id(@match, slot)) &&
            "font-bold"
        ]}
      >
        {slot_label(@match, slot)}
      </p>
    </li>
    """
  end

  defp schedule_match_label(%{group: %Group{} = group}),
    do: "#{group.stage.category.name} · #{group.name}"

  defp schedule_match_label(%{stage: %Stage{} = stage} = match),
    do: "#{stage.category.name} · #{stage.name} - #{round_label(match.round, stage.rounds)}"

  defp unscheduled_modal_title({:table, table}),
    do: gettext("Adicionar jogo à mesa %{table}", table: table.name)

  defp unscheduled_modal_title(:any), do: gettext("Partidas sem mesa")

  defp filter_unscheduled(matches, nil), do: matches

  defp filter_unscheduled(matches, category_id),
    do: Enum.filter(matches, &(schedule_match_category(&1).id == category_id))

  defp schedule_match_category(%{group: %Group{stage: stage}}), do: stage.category
  defp schedule_match_category(%{stage: %Stage{} = stage}), do: stage.category

  defp slot_registration_id(match, 1), do: match.registration1_id
  defp slot_registration_id(match, 2), do: match.registration2_id

  attr :name, :string, required: true
  attr :won, :boolean, required: true
  attr :has_sets, :boolean, required: true
  attr :set_wins, :integer, required: true
  attr :scores, :list, required: true

  defp match_card_row(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class="flex min-w-0 flex-1 items-center gap-2">
        <span class={["min-w-0 truncate text-sm", @won && "font-bold"]}>{@name}</span>
        <.icon :if={@won} name="hero-check-micro" class="shrink-0 text-primary" />
      </div>
      <span :if={@has_sets} class="w-5 shrink-0 text-center text-sm font-bold tabular-nums">
        {@set_wins}
      </span>
      <div class="flex gap-1">
        <span :for={score <- @scores} class="w-7 text-center text-xs text-fg-muted tabular-nums">
          {score}
        </span>
      </div>
    </div>
    """
  end

  attr :registration, :any, required: true
  attr :label, :any, required: true
  attr :won, :boolean, required: true
  attr :is_bye, :boolean, default: false
  attr :set_wins, :any, required: true, doc: "number of sets won, or false to hide"

  defp bracket_slot(assigns) do
    ~H"""
    <div class={["flex items-center gap-2 px-4 py-2", winner_bg(@registration, @won)]}>
      <div class="flex min-w-0 flex-1 items-center gap-2">
        <.label_and_player registration={@registration} label={@label} won={@won} is_bye={@is_bye} />
        <.icon :if={@won} name="hero-check-mini" class="shrink-0 text-primary" />
      </div>
      <span :if={@set_wins} class={["text-sm tabular-nums", @won && "font-bold"]}>
        {@set_wins}
      </span>
    </div>
    """
  end

  attr :on_cancel, :string, required: true

  defp modal_actions(assigns) do
    ~H"""
    <.form_actions align="end">
      <.button type="button" phx-click={@on_cancel}>{gettext("Cancelar")}</.button>
      <.button type="submit" variant="primary">{gettext("Salvar")}</.button>
    </.form_actions>
    """
  end

  attr :registration, :any, required: true
  attr :label, :any, required: true
  attr :won, :boolean, required: true
  attr :is_bye, :boolean, default: false

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
    <span :if={@name && @label} class="shrink-0 text-xs whitespace-nowrap text-fg-muted">
      {@label}
    </span>
    <span class={["truncate text-sm", @won && "font-bold"]}>
      {@name || @label || if(@is_bye, do: gettext("Bye"), else: gettext("TBD"))}
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

  defp unregistered_players(socket) do
    case socket.assigns.active_category do
      nil ->
        socket.assigns.players

      category ->
        registered_ids =
          Registrations.list_registered_player_ids(socket.assigns.event.id, category.id)

        Enum.reject(socket.assigns.players, &MapSet.member?(registered_ids, &1.id))
    end
  end

  defp ensure_player_id(attrs, socket) do
    case socket.assigns[:selected_player_id] do
      nil -> attrs
      id -> Map.put(attrs, "player_id", to_string(id))
    end
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
      _ -> if match.is_bye, do: gettext("Bye"), else: gettext("TBD")
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

  defp max_count(rows), do: Enum.reduce(rows, 0, fn row, acc -> max(row.count, acc) end)

  defp winner_bg(%Registration{final_standing: 1}, _won), do: "bg-gold/15"
  defp winner_bg(%Registration{final_standing: 2}, _won), do: "bg-silver/20"
  defp winner_bg(_registration, true), do: "bg-primary/10"
  defp winner_bg(_registration, _won), do: nil

  defp winner_options(match) do
    for {n, registration, registration_id} <- [
          {1, match.registration1, match.registration1_id},
          {2, match.registration2, match.registration2_id}
        ],
        is_struct(registration, Registration),
        do: {slot_label(match, n), registration_id}
  end

  attr :final_standing, :any, required: true

  defp final_standing(%{final_standing: nil} = assigns), do: ~H""

  defp final_standing(assigns) do
    {text, tone} =
      case assigns.final_standing do
        1 -> {gettext("Campeão 🥇"), "gold"}
        2 -> {gettext("Vice-campeão 🥈"), "silver"}
        3 -> {gettext("3º lugar 🥉"), "bronze"}
        n -> {gettext("%{position}º lugar", position: n), "primary"}
      end

    assigns = assign(assigns, text: text, tone: tone)

    ~H"""
    <div>
      <.badge tone={@tone}>{@text}</.badge>
    </div>
    """
  end
end
