defmodule T3SystemWeb.EventLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Clubs
  alias T3System.Events
  alias T3System.Matches
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.Stage
  alias T3System.Players
  alias T3System.Registrations
  alias T3System.Registrations.Registration

  @fixed_tabs ~w(overview matches)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
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
        <div class="px-8 border-b border-slate-100">
          <nav aria-label={gettext("Tabs")} class="flex gap-4">
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

        <%!-- Tab: Overview --%>
        <div :if={@current_tab == "overview"} class="p-8">
          <div :if={@is_superuser} class="mb-4 flex justify-end">
            <.button phx-click="open_new_registration" variant="primary">
              <.icon name="hero-plus" /> {gettext("Add Registration")}
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
            <div :if={@is_superuser and @all_match_cards != []} class="mb-4 flex justify-end">
              <.button phx-click="open_new_match" variant="primary">
                <.icon name="hero-plus" /> {gettext("Add Match")}
              </.button>
            </div>

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
                  {gettext("Edit Stage")}
                </button>
                <button
                  phx-click="delete_stage"
                  data-confirm={
                    gettext("Are you sure? This will delete all groups and matches in this stage.")
                  }
                  class="text-xs text-red-400 hover:text-red-300"
                >
                  {gettext("Delete Stage")}
                </button>
              </div>
              <div class="flex gap-2">
                <.button
                  :if={@current_stage.type == "group"}
                  phx-click="open_new_group"
                  variant="primary"
                >
                  <.icon name="hero-plus" /> {gettext("Add Group")}
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
                  <p class="text-sky-400">{gettext("Finalizado")}</p>
                </div>

                <div :if={standings == []} class="p-4 text-sm">
                  {gettext("No players yet.")}
                </div>

                <div :if={standings != []} class="overflow-x-auto">
                  <table class="w-full text-sm">
                    <thead>
                      <tr class="border-b border-white/10 text-left text-xs text-slate-100/60">
                        <th class="w-1 pb-2 pl-4 font-normal">#</th>
                        <th class="pb-2 px-2 font-normal">{gettext("Player")}</th>
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
                      {gettext("Players")}
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
              <div :if={@is_superuser} class="mb-4 flex items-center justify-end">
                <button
                  phx-click="open_bracket_setup"
                  class="text-xs text-indigo-400 hover:text-indigo-300"
                >
                  {gettext("Reconfigure")}
                </button>
              </div>

              <%!-- Bracket visualization --%>
              <div class="overflow-x-auto pb-6 -mx-4 px-4">
                <div class="flex min-w-max">
                  <div
                    :for={{round, matches} <- @stage_bracket_rounds}
                    style="width: 224px; flex-shrink: 0;"
                  >
                    <%!-- Round header --%>
                    <div class="mb-3 h-8 flex items-end pl-3 pb-1 text-xs font-bold uppercase tracking-wider text-gray-400">
                      {round_label(round, @current_stage.rounds)}
                    </div>
                    <%!-- Match slots --%>
                    <div
                      :for={match <- matches}
                      id={"bracket-match-#{match.id}"}
                      style={"position: relative; height: #{slot_height(round)}px;"}
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
                        :if={round > 1}
                        style="position: absolute; left: 0; width: 12px; top: 50%; height: 2px; background-color: rgba(99,102,241,0.25);"
                      >
                      </div>

                      <%!-- Match card, vertically centered in slot --%>
                      <div style="position: absolute; top: 50%; transform: translateY(-50%); left: 12px; right: 24px;">
                        <div class="overflow-hidden rounded-lg bg-white/5">
                          <%!-- Player 1 --%>
                          <div class={[
                            "flex items-center gap-1.5 px-2.5 py-2",
                            if(p1_won, do: "bg-white/5")
                          ]}>
                            <.icon
                              :if={p1_won}
                              name="hero-check"
                              class="size-3 shrink-0 text-green-400"
                            />
                            <span :if={!p1_won} class="size-3 shrink-0"></span>
                            <span class={[
                              "min-w-0 flex-1 truncate text-sm",
                              if(p1_won, do: "font-semibold text-white", else: "text-gray-300")
                            ]}>
                              {slot_label(match, 1)}
                            </span>
                            <span
                              :if={sorted_sets != []}
                              class={[
                                "tabular-nums text-sm font-bold",
                                if(p1_won, do: "text-white", else: "text-gray-400")
                              ]}
                            >
                              {sw1}
                            </span>
                          </div>
                          <div class="h-px bg-white/10"></div>
                          <%!-- Player 2 --%>
                          <div class={[
                            "flex items-center gap-1.5 px-2.5 py-2",
                            if(p2_won, do: "bg-white/5")
                          ]}>
                            <.icon
                              :if={p2_won}
                              name="hero-check"
                              class="size-3 shrink-0 text-green-400"
                            />
                            <span :if={!p2_won} class="size-3 shrink-0"></span>
                            <span class={[
                              "min-w-0 flex-1 truncate text-sm",
                              if(p2_won, do: "font-semibold text-white", else: "text-gray-300")
                            ]}>
                              {slot_label(match, 2)}
                            </span>
                            <span
                              :if={sorted_sets != []}
                              class={[
                                "tabular-nums text-sm font-bold",
                                if(p2_won, do: "text-white", else: "text-gray-400")
                              ]}
                            >
                              {sw2}
                            </span>
                          </div>
                          <%!-- Superuser actions --%>
                          <div
                            :if={@is_superuser}
                            class="flex justify-end gap-2 border-t border-white/5 px-2.5 py-1"
                          >
                            <button
                              :if={round == 1}
                              phx-click="open_assign_slot"
                              phx-value-id={match.id}
                              class="text-xs text-gray-500 hover:text-gray-400"
                            >
                              {gettext("Assign")}
                            </button>
                            <button
                              phx-click="open_score_modal"
                              phx-value-id={match.id}
                              class="text-xs text-indigo-400/70 hover:text-indigo-300"
                            >
                              {gettext("Scores")}
                            </button>
                            <button
                              phx-click="delete_bracket_match"
                              phx-value-id={match.id}
                              data-confirm={gettext("Are you sure?")}
                              class="text-xs text-red-400/70 hover:text-red-300"
                            >
                              {gettext("Del")}
                            </button>
                          </div>
                        </div>
                      </div>

                      <%!-- Right connector: top of pair (odd position) --%>
                      <div
                        :if={round < @current_stage.rounds and rem(match.position, 2) == 1}
                        style="position: absolute; right: 0; width: 24px; top: 50%; height: 50%; border-top: 2px solid rgba(99,102,241,0.3); border-right: 2px solid rgba(99,102,241,0.3);"
                      >
                      </div>

                      <%!-- Right connector: bottom of pair (even position) --%>
                      <div
                        :if={round < @current_stage.rounds and rem(match.position, 2) == 0}
                        style="position: absolute; right: 0; width: 24px; top: 0; height: 50%; border-bottom: 2px solid rgba(99,102,241,0.3); border-right: 2px solid rgba(99,102,241,0.3);"
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

        <%!-- Manage players modal --%>
        <div :if={@players_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_players_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {gettext("Manage Players")} — {@players_modal.name}
                </h2>
                <button phx-click="close_players_modal" class="text-gray-400 hover:text-white">
                  <span class="sr-only">{gettext("Close")}</span>
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <%!-- Current members --%>
              <div class="mb-4">
                <p class="mb-2 text-xs font-medium uppercase tracking-wide text-gray-400">
                  {gettext("Players")} ({length(@players_modal.registrations)})
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
                    <option value="">{gettext("Select a player...")}</option>
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
                    <p class="text-sm text-white">{gettext("Generate Matches")}</p>
                    <p class="text-xs text-gray-400">
                      {gettext("Round-robin for all players. Replaces existing matches.")}
                    </p>
                  </div>
                  <.button
                    phx-click="generate_matches"
                    variant="primary"
                    disabled={length(@players_modal.registrations) < 2}
                  >
                    {gettext("Generate")}
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
                    do: gettext("Add Group"),
                    else: gettext("Edit Group")}
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
                <.input
                  field={@group_form[:name]}
                  type="text"
                  label={gettext("Name")}
                />
                <.input
                  field={@group_form[:qualifies_count]}
                  type="number"
                  label={gettext("Players advancing")}
                />
                <input
                  type="hidden"
                  name="group[stage_id]"
                  value={@current_stage && @current_stage.id}
                />
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_group_modal">
                    {gettext("Cancel")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Save")}</.button>
                </div>
              </.form>
            </div>
          </div>
        </div>

        <%!-- Match modal --%>
        <div :if={@match_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_match_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {if @match_modal == :new,
                    do: gettext("Add Match"),
                    else: gettext("Edit Match")}
                </h2>
                <button phx-click="close_match_modal" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <.form
                :if={@match_form}
                for={@match_form}
                id="match-form"
                phx-change="validate_match"
                phx-submit="save_match"
              >
                <.input
                  field={@match_form[:group_id]}
                  type="select"
                  label={gettext("Group")}
                  options={Enum.map(@groups_with_standings, fn {g, _} -> {g.name, g.id} end)}
                  disabled={@match_modal != :new}
                />
                <% reg1_val = to_string(@match_form[:registration1_id].value || "") %>
                <% reg2_val = to_string(@match_form[:registration2_id].value || "") %>
                <.input
                  field={@match_form[:registration1_id]}
                  type="select"
                  label={gettext("Player 1")}
                  options={
                    @match_group_regs
                    |> Enum.reject(&(to_string(&1.id) == reg2_val))
                    |> Enum.map(&{&1.player.name, &1.id})
                  }
                  prompt={gettext("Select a player")}
                />
                <.input
                  field={@match_form[:registration2_id]}
                  type="select"
                  label={gettext("Player 2")}
                  options={
                    @match_group_regs
                    |> Enum.reject(&(to_string(&1.id) == reg1_val))
                    |> Enum.map(&{&1.player.name, &1.id})
                  }
                  prompt={gettext("Select a player")}
                />
                <.input
                  field={@match_form[:scheduled_at]}
                  type="datetime-local"
                  label={gettext("When")}
                />
                <input type="hidden" name="match[event_id]" value={@event.id} />
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_match_modal">
                    {gettext("Cancel")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Save")}</.button>
                </div>
              </.form>
            </div>
          </div>
        </div>

        <%!-- Scores modal --%>
        <div :if={@score_modal != nil} class="fixed inset-0 z-50">
          <div class="absolute inset-0 bg-black/60" phx-click="close_score_modal"></div>
          <div class="relative flex h-full items-center justify-center pointer-events-none">
            <div class="w-full max-w-md rounded-lg bg-gray-900 p-6 shadow-xl pointer-events-auto">
              <% {sm_match, _sm_context} = @score_modal %>
              <% sm_sets_by_num = Map.new(sm_match.sets, &{&1.set_number, &1}) %>
              <div class="mb-4 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">
                  {gettext("Edit Scores")}
                </h2>
                <button phx-click="close_score_modal" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <form id="score-form" phx-submit="save_scores">
                <%!-- Column headers --%>
                <div class="mb-1 flex items-center gap-2 text-xs text-gray-400">
                  <span class="w-14 shrink-0"></span>
                  <span class="flex-1 truncate text-center font-medium">
                    {slot_label(sm_match, 1)}
                  </span>
                  <span class="w-4 shrink-0 text-center text-gray-600">vs</span>
                  <span class="flex-1 truncate text-center font-medium">
                    {slot_label(sm_match, 2)}
                  </span>
                  <span class="w-16 shrink-0 text-center font-medium">
                    {gettext("W")}
                  </span>
                </div>
                <%!-- Set rows --%>
                <div :for={n <- 1..@score_set_count} class="mb-1.5 flex items-center gap-2">
                  <% sm_set = Map.get(sm_sets_by_num, n) %>
                  <input :if={sm_set} type="hidden" name={"sets[#{n - 1}][id]"} value={sm_set.id} />
                  <input type="hidden" name={"sets[#{n - 1}][set_number]"} value={n} />
                  <span class="w-14 shrink-0 text-xs text-gray-400">
                    {gettext("Set %{n}", n: n)}
                  </span>
                  <input
                    type="number"
                    name={"sets[#{n - 1}][score1]"}
                    value={sm_set && sm_set.score1}
                    min="0"
                    class="flex-1 rounded border border-white/10 bg-gray-800 px-2 py-1 text-center text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  />
                  <span class="w-4 shrink-0 text-center text-xs text-gray-600">–</span>
                  <input
                    type="number"
                    name={"sets[#{n - 1}][score2]"}
                    value={sm_set && sm_set.score2}
                    min="0"
                    class="flex-1 rounded border border-white/10 bg-gray-800 px-2 py-1 text-center text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  />
                  <select
                    name={"sets[#{n - 1}][winner_registration_id]"}
                    class="w-16 shrink-0 rounded border border-white/10 bg-gray-800 px-1 py-1 text-center text-xs text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  >
                    <option value="">–</option>
                    <option
                      :if={is_struct(sm_match.registration1, Registration)}
                      value={sm_match.registration1_id}
                      selected={sm_set && sm_set.winner_registration_id == sm_match.registration1_id}
                    >
                      P1
                    </option>
                    <option
                      :if={is_struct(sm_match.registration2, Registration)}
                      value={sm_match.registration2_id}
                      selected={sm_set && sm_set.winner_registration_id == sm_match.registration2_id}
                    >
                      P2
                    </option>
                  </select>
                </div>
                <%!-- Add set button --%>
                <button
                  type="button"
                  phx-click="add_score_row"
                  class="mt-1 text-xs text-indigo-400 hover:text-indigo-300"
                >
                  + {gettext("Add set")}
                </button>
                <%!-- Match Winner --%>
                <div class="mt-3">
                  <label class="mb-1 block text-sm font-medium text-gray-300">
                    {gettext("Match Winner")}
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
                    {gettext("Cancel")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Save")}</.button>
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
                    {gettext("Cancel")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Save")}</.button>
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
                  {gettext("Assign Players")}
                </h2>
                <button phx-click="close_assign_slot" class="text-gray-400 hover:text-white">
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>

              <form id="assign-slot-form" phx-submit="save_assign_slot">
                <%!-- Slot 1 --%>
                <p class="mb-2 text-xs font-medium uppercase tracking-wide text-gray-400">
                  {gettext("Player 1")}
                </p>
                <div class="mb-5 space-y-3">
                  <div>
                    <label class="mb-1 block text-sm text-gray-300">
                      {gettext("Placeholder label")}
                    </label>
                    <input
                      type="text"
                      name="slot1_label"
                      value={@assign_slot_modal.slot1_label}
                      placeholder={gettext("e.g. 1st Group B")}
                      class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div>
                    <label class="mb-1 block text-sm text-gray-300">{gettext("Assignment")}</label>
                    <select
                      name="slot1_type"
                      class="mb-2 w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    >
                      <option value="none" selected={is_nil(@assign_slot_modal.registration1_id)}>
                        {gettext("None (show label)")}
                      </option>
                      <option
                        value="direct"
                        selected={not is_nil(@assign_slot_modal.registration1_id)}
                      >
                        {gettext("Direct")}
                      </option>
                      <option value="bye">{gettext("Bye / WO")}</option>
                    </select>
                    <select
                      name="slot1_registration_id"
                      class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    >
                      <option value="">{gettext("Select player")}</option>
                      <option
                        :for={r <- @stage_bracket_registrations}
                        value={r.id}
                        selected={@assign_slot_modal.registration1_id == r.id}
                      >
                        {r.player.name} — {r.club.name}
                      </option>
                    </select>
                  </div>
                </div>

                <%!-- Slot 2 --%>
                <p class="mb-2 text-xs font-medium uppercase tracking-wide text-gray-400">
                  {gettext("Player 2")}
                </p>
                <div class="mb-4 space-y-3">
                  <div>
                    <label class="mb-1 block text-sm text-gray-300">
                      {gettext("Placeholder label")}
                    </label>
                    <input
                      type="text"
                      name="slot2_label"
                      value={@assign_slot_modal.slot2_label}
                      placeholder={gettext("e.g. 2nd Group A")}
                      class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div>
                    <label class="mb-1 block text-sm text-gray-300">{gettext("Assignment")}</label>
                    <select
                      name="slot2_type"
                      class="mb-2 w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    >
                      <option value="none" selected={is_nil(@assign_slot_modal.registration2_id)}>
                        {gettext("None (show label)")}
                      </option>
                      <option
                        value="direct"
                        selected={not is_nil(@assign_slot_modal.registration2_id)}
                      >
                        {gettext("Direct")}
                      </option>
                      <option value="bye">{gettext("Bye / WO")}</option>
                    </select>
                    <select
                      name="slot2_registration_id"
                      class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    >
                      <option value="">{gettext("Select player")}</option>
                      <option
                        :for={r <- @stage_bracket_registrations}
                        value={r.id}
                        selected={@assign_slot_modal.registration2_id == r.id}
                      >
                        {r.player.name} — {r.club.name}
                      </option>
                    </select>
                  </div>
                </div>

                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_assign_slot">
                    {gettext("Cancel")}
                  </.button>
                  <.button type="submit" variant="primary">{gettext("Save")}</.button>
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
                    do: gettext("Add Stage"),
                    else: gettext("Edit Stage")}
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
                <.input
                  field={@stage_form[:name]}
                  type="text"
                  label={gettext("Name")}
                />
                <.input
                  :if={@stage_modal == :new}
                  field={@stage_form[:type]}
                  type="select"
                  label={gettext("Type")}
                  options={[{gettext("Group"), "group"}, {gettext("Bracket"), "bracket"}]}
                />
                <.input
                  field={@stage_form[:order]}
                  type="number"
                  label={gettext("Order")}
                />
                <.input
                  :if={to_string(@stage_form[:type].value) == "bracket"}
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
                <div class="mt-4 flex justify-end gap-2">
                  <.button type="button" phx-click="close_stage_modal">
                    {gettext("Cancel")}
                  </.button>
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
      |> assign(:is_superuser, is_superuser)
      |> assign(:category_form, to_form(%{"category_id" => nil}, as: :category))
      |> assign(:tabs, @fixed_tabs)
      |> assign(:stages, [])
      |> assign(:current_stage, nil)
      |> assign(:stage_bracket_rounds, [])
      |> assign(:modal, nil)
      |> assign(:form, nil)
      |> assign(:group_modal, nil)
      |> assign(:group_form, nil)
      |> assign(:players_modal, nil)
      |> assign(:category_registrations, [])
      |> assign(:groups_with_standings, [])
      |> assign(:match_modal, nil)
      |> assign(:match_form, nil)
      |> assign(:match_group, nil)
      |> assign(:match_group_regs, [])
      |> assign(:score_modal, nil)
      |> assign(:score_set_count, 3)
      |> assign(:all_match_cards, [])
      |> assign(:bracket_modal, nil)
      |> assign(:bracket_form, nil)
      |> assign(:stage_bracket_registrations, [])
      |> assign(:assign_slot_modal, nil)
      |> assign(:stage_modal, nil)
      |> assign(:stage_form, nil)
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
    active_category = resolve_category(event, params["category_id"])
    stages = load_stages(event, active_category)
    {tabs, tab} = resolve_tabs(stages, params["tab"])
    current_stage = find_current_stage(tab, stages)

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
      |> load_stage_data(current_stage)
      |> assign_all_match_cards()

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_category", %{"category" => %{"category_id" => id}}, socket) do
    # When switching categories, go back to overview since stage tabs will change
    {:noreply,
     push_patch(socket,
       to: ~p"/events/#{socket.assigns.event}?tab=overview&category_id=#{id}"
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

  # Match management (superuser only)

  def handle_event("open_new_match", _params, socket) do
    {match_struct, group, group_regs} =
      case socket.assigns.groups_with_standings do
        [{first_group, _} | _] ->
          g = Matches.get_group_with_registrations!(first_group.id)
          {%Match{group_id: first_group.id}, g, g.registrations}

        _ ->
          {%Match{}, nil, []}
      end

    form = Matches.change_match(match_struct) |> to_form()

    {:noreply,
     assign(socket,
       match_modal: :new,
       match_form: form,
       match_group: group,
       match_group_regs: group_regs
     )}
  end

  def handle_event("open_edit_match", %{"id" => id}, socket) do
    match = Matches.get_match!(id)
    group = Matches.get_group_with_registrations!(match.group_id)
    form = Matches.change_match(match) |> to_form()

    {:noreply,
     assign(socket,
       match_modal: {:edit, match},
       match_form: form,
       match_group: group,
       match_group_regs: group.registrations
     )}
  end

  def handle_event("close_match_modal", _params, socket) do
    {:noreply,
     assign(socket, match_modal: nil, match_form: nil, match_group: nil, match_group_regs: [])}
  end

  def handle_event("validate_match", %{"match" => attrs}, socket) do
    match_struct =
      case socket.assigns.match_modal do
        {:edit, match} -> match
        _ -> %Match{}
      end

    form =
      Matches.change_match(match_struct, attrs)
      |> Map.put(:action, :validate)
      |> to_form()

    socket = assign(socket, :match_form, form)

    socket =
      case attrs["group_id"] do
        "" ->
          socket
          |> assign(:match_group, nil)
          |> assign(:match_group_regs, [])

        group_id_str when is_binary(group_id_str) ->
          case Integer.parse(group_id_str) do
            {group_id, ""} ->
              group = Matches.get_group_with_registrations!(group_id)

              socket
              |> assign(:match_group, group)
              |> assign(:match_group_regs, group.registrations)

            _ ->
              socket
          end

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("save_match", %{"match" => attrs}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.match_modal do
        {:edit, match} -> Matches.update_match(scope, match, attrs)
        _ -> Matches.create_match(scope, attrs)
      end

    case result do
      {:ok, _match} ->
        {:noreply,
         socket
         |> reload_stage_data()
         |> assign(match_modal: nil, match_form: nil, match_group: nil, match_group_regs: [])}

      {:error, changeset} ->
        {:noreply, assign(socket, :match_form, to_form(changeset))}
    end
  end

  def handle_event("delete_match", %{"id" => id}, socket) do
    match = Matches.get_match!(id)
    {:ok, _} = Matches.delete_match(socket.assigns.current_scope, match)
    {:noreply, reload_stage_data(socket)}
  end

  # Score management (superuser only)

  def handle_event("open_score_modal", %{"id" => id}, socket) do
    match_id = String.to_integer(id)

    score_modal =
      find_match_in_groups(match_id, socket.assigns.groups_with_standings) ||
        find_match_in_stage(match_id, socket.assigns.current_stage)

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

  def handle_event("save_scores", params, socket) do
    {match, _context} = socket.assigns.score_modal
    scope = socket.assigns.current_scope

    filtered_sets =
      (params["sets"] || %{})
      |> Enum.reject(fn {_, s} ->
        s["score1"] in [nil, ""] and s["score2"] in [nil, ""] and
          s["winner_registration_id"] in [nil, ""]
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
      if stage.rounds do
        Matches.reconfigure_stage_bracket(scope, stage, rounds)
      else
        Matches.update_stage(scope, stage, %{rounds: rounds})
        |> case do
          {:ok, updated_stage} ->
            Matches.reconfigure_stage_bracket(scope, updated_stage, rounds)

          error ->
            error
        end
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

  def handle_event("delete_bracket_match", %{"id" => id}, socket) do
    match = Matches.get_match!(id)
    {:ok, _} = Matches.delete_match(socket.assigns.current_scope, match)
    {:noreply, reload_stage_data(socket)}
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

    result =
      with {:ok, _} <- Matches.update_match(scope, match, label_attrs),
           fresh_match = Matches.get_match!(match.id),
           {:ok, _} <- assign_slot(scope, fresh_match, 1, params),
           fresh_match2 = Matches.get_match!(match.id),
           {:ok, _} <- assign_slot(scope, fresh_match2, 2, params) do
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

  defp resolve_tabs(stages, tab_param) do
    stage_tabs = Enum.map(stages, fn s -> "stage-#{s.id}" end)
    tabs = @fixed_tabs ++ stage_tabs
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

  defp assign_slot(scope, match, slot, params) do
    n = Integer.to_string(slot)

    case params["slot#{n}_type"] do
      "bye" ->
        Matches.assign_bracket_slot_direct(scope, match, slot, nil)

      "direct" ->
        reg_id = params["slot#{n}_registration_id"]
        registration_id = if reg_id in ["", nil], do: nil, else: String.to_integer(reg_id)
        Matches.assign_bracket_slot_direct(scope, match, slot, registration_id)

      _ ->
        {:ok, :skip}
    end
  end

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
      |> Enum.sort_by(fn card -> {card.scheduled_at, card.id} end)

    assign(socket, :all_match_cards, cards)
  end

  defp assign_all_match_cards(socket), do: socket

  defp stage_match_cards(stage) do
    group_cards =
      Enum.flat_map(stage.groups, fn group ->
        ctx = %{label: "#{stage.name} — #{group.name}", source: :group}
        Enum.map(group.matches, &prepare_match_card(&1, ctx))
      end)

    bracket_cards =
      if stage.type == "bracket" and stage.rounds do
        Enum.flat_map(compute_bracket_rounds(stage), fn {round, matches} ->
          ctx = %{
            label: "#{stage.name} — #{round_label(round, stage.rounds)}",
            source: :bracket
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

  defp find_match_in_groups(match_id, groups_with_standings) do
    Enum.find_value(groups_with_standings, fn {g, _} ->
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

  defp prepare_match_card(match, %{label: label, source: source}) do
    sorted_sets = sort_sets(match.sets)

    sw1 = Enum.count(sorted_sets, &(&1.winner_registration_id == match.registration1_id))
    sw2 = Enum.count(sorted_sets, &(&1.winner_registration_id == match.registration2_id))

    %{
      id: match.id,
      label: label,
      source: source,
      scheduled_at: match.scheduled_at,
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
      p2_name: card_player_name(match, 2, source)
    }
  end

  defp sort_sets(%Ecto.Association.NotLoaded{}), do: []
  defp sort_sets(sets), do: Enum.sort_by(sets, & &1.set_number)

  defp format_set_score(nil), do: "–"
  defp format_set_score(score), do: to_string(score)

  defp card_player_name(match, 1, :group), do: match_player_name(match.registration1)
  defp card_player_name(match, 2, :group), do: match_player_name(match.registration2)
  defp card_player_name(match, slot, :bracket), do: slot_label(match, slot)

  defp match_card(assigns) do
    ~H"""
    <div id={"match-#{@card.id}"} class="rounded-sm bg-slate-800 shadow-xl">
      <%!-- Card header --%>
      <div class="flex items-center justify-between p-4 pb-2 border-b border-slate-100/20">
        <div>
          <p class="font-display font-bold text-sm text-slate-100/60">{@card.label}</p>
          <p :if={@card.scheduled_at} class="mt-0.5 text-xs text-slate-100">
            {Calendar.strftime(@card.scheduled_at, "%d/%m %H:%M")}
          </p>
        </div>
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
          :if={@card.source == :group}
          phx-click="open_edit_match"
          phx-value-id={@card.id}
          class="text-xs text-indigo-400 hover:text-indigo-300"
        >
          {gettext("Edit")}
        </button>
        <button
          phx-click="open_score_modal"
          phx-value-id={@card.id}
          class="text-xs text-indigo-400 hover:text-indigo-300"
        >
          {gettext("Scores")}
        </button>
        <button
          phx-click={if(@card.source == :group, do: "delete_match", else: "delete_bracket_match")}
          phx-value-id={@card.id}
          data-confirm={gettext("Are you sure?")}
          class="text-xs text-red-400 hover:text-red-300"
        >
          {gettext("Delete")}
        </button>
      </div>
    </div>
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

  defp tab_label("overview", _stages), do: gettext("Overview")
  defp tab_label("matches", _stages), do: gettext("Matches")

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
      1 -> gettext("Semifinals")
      2 -> gettext("Quarterfinals")
      3 -> gettext("Round of 16")
      4 -> gettext("Round of 32")
      5 -> gettext("Round of 64")
      6 -> gettext("Round of 128")
      _ -> gettext("Round %{n}", n: round)
    end
  end

  defp slot_label(match, 1) do
    cond do
      is_struct(match.registration1, Registration) -> match.registration1.player.name
      match.slot1_label not in [nil, ""] -> match.slot1_label
      true -> gettext("TBD")
    end
  end

  defp slot_label(match, 2) do
    cond do
      is_struct(match.registration2, Registration) -> match.registration2.player.name
      match.slot2_label not in [nil, ""] -> match.slot2_label
      true -> gettext("TBD")
    end
  end

  # Height in px for one bracket slot at the given round (doubles each round).
  defp slot_height(round), do: 88 * trunc(:math.pow(2, round - 1))

  defp match_player_name(%{player: %{name: name}}), do: name
  defp match_player_name(_), do: gettext("TBD")
end
