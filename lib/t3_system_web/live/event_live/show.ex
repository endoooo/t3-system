defmodule T3SystemWeb.EventLive.Show do
  use T3SystemWeb, :live_view

  alias T3System.Clubs
  alias T3System.Events
  alias T3System.Matches
  alias T3System.Matches.Group
  alias T3System.Matches.Match
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

        <%!-- Tab: Groups --%>
        <div :if={@current_tab == "groups"}>
          <div :if={@active_category}>
            <div :if={@is_superuser} class="mb-4 flex justify-end">
              <.button phx-click="open_new_group" variant="primary">
                <.icon name="hero-plus" /> {gettext("Add Group")}
              </.button>
            </div>

            <p :if={@groups_with_standings == []} class="text-gray-400 text-sm">
              {gettext("No groups yet.")}
            </p>

            <div
              :for={{group, standings} <- @groups_with_standings}
              id={"group-#{group.id}"}
              class="mb-8"
            >
              <div class="mb-3 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-white">{group.name}</h2>
                <div :if={@is_superuser} class="flex gap-3">
                  <button
                    phx-click="open_manage_players"
                    phx-value-id={group.id}
                    class="text-xs text-gray-400 hover:text-gray-300"
                  >
                    {gettext("Players")}
                  </button>
                  <button
                    phx-click="open_edit_group"
                    phx-value-id={group.id}
                    class="text-xs text-indigo-400 hover:text-indigo-300"
                  >
                    {gettext("Edit")}
                  </button>
                  <button
                    phx-click="delete_group"
                    phx-value-id={group.id}
                    data-confirm={gettext("Are you sure?")}
                    class="text-xs text-red-400 hover:text-red-300"
                  >
                    {gettext("Delete")}
                  </button>
                </div>
              </div>

              <div :if={standings == []} class="text-sm text-gray-400">
                {gettext("No players yet.")}
              </div>

              <div :if={standings != []} class="overflow-x-auto">
                <table class="w-full text-sm">
                  <thead>
                    <tr class="border-b border-white/10 text-left text-xs text-gray-400">
                      <th class="pb-2 pr-3 font-medium">#</th>
                      <th class="pb-2 pr-3 font-medium">{gettext("Player")}</th>
                      <th class="pb-2 pr-3 font-medium">{gettext("Club")}</th>
                      <th class="pb-2 pr-3 text-center font-medium">{gettext("P")}</th>
                      <th class="pb-2 pr-3 text-center font-medium">{gettext("W")}</th>
                      <th class="pb-2 pr-3 text-center font-medium">{gettext("L")}</th>
                      <th class="pb-2 pr-3 text-center font-medium">{gettext("SD")}</th>
                      <th class="pb-2 pr-3 text-center font-medium">{gettext("PD")}</th>
                      <th class="pb-2 font-medium">{gettext("Status")}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      :for={row <- standings}
                      class="border-b border-white/5 last:border-0"
                    >
                      <td class="py-2 pr-3 text-gray-400">{row.rank}</td>
                      <td class="py-2 pr-3 font-medium text-white">
                        {row.registration.player.name}
                      </td>
                      <td class="py-2 pr-3 text-gray-400">{row.registration.club.name}</td>
                      <td class="py-2 pr-3 text-center text-gray-300">{row.played}</td>
                      <td class="py-2 pr-3 text-center text-gray-300">{row.won}</td>
                      <td class="py-2 pr-3 text-center text-gray-300">{row.lost}</td>
                      <td class={[
                        "py-2 pr-3 text-center",
                        if(row.set_diff >= 0, do: "text-green-400", else: "text-red-400")
                      ]}>
                        {format_diff(row.set_diff)}
                      </td>
                      <td class={[
                        "py-2 pr-3 text-center",
                        if(row.point_diff >= 0, do: "text-green-400", else: "text-red-400")
                      ]}>
                        {format_diff(row.point_diff)}
                      </td>
                      <td class="py-2">
                        <span
                          :if={row.qualified}
                          class="inline-flex items-center rounded-full bg-green-400/10 px-2 py-0.5 text-xs font-medium text-green-400"
                        >
                          {gettext("Qualified")}
                        </span>
                        <span
                          :if={!row.qualified}
                          class="inline-flex items-center rounded-full bg-white/5 px-2 py-0.5 text-xs font-medium text-gray-400"
                        >
                          {gettext("Not qualified")}
                        </span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <p :if={!@active_category} class="text-gray-400 text-sm">
            {gettext("No category selected.")}
          </p>
        </div>

        <%!-- Tab: Matches --%>
        <div :if={@current_tab == "matches"}>
          <div :if={@active_category}>
            <div :if={@is_superuser and @groups_with_standings != []} class="mb-4 flex justify-end">
              <.button phx-click="open_new_match" variant="primary">
                <.icon name="hero-plus" /> {gettext("Add Match")}
              </.button>
            </div>

            <% all_matches =
              @groups_with_standings
              |> Enum.flat_map(fn {group, _} -> Enum.map(group.matches, &{&1, group}) end)
              |> Enum.sort_by(fn {m, _} -> {m.scheduled_at, m.id} end) %>

            <p :if={all_matches == []} class="text-gray-400 text-sm">
              {gettext("No matches yet.")}
            </p>

            <div class="space-y-3">
              <div
                :for={{match, group} <- all_matches}
                id={"match-#{match.id}"}
                class="rounded-lg bg-white/5"
              >
                <% sorted_sets =
                  case match.sets do
                    %Ecto.Association.NotLoaded{} -> []
                    sets -> Enum.sort_by(sets, & &1.set_number)
                  end %>
                <% best_of = match.best_of || group.best_of %>
                <% sets_by_number = Map.new(sorted_sets, fn s -> {s.set_number, s} end) %>
                <% p1_scores =
                  Enum.map(1..best_of, fn n ->
                    case Map.get(sets_by_number, n) do
                      nil -> "–"
                      s -> if is_nil(s.score1), do: "–", else: to_string(s.score1)
                    end
                  end) %>
                <% p2_scores =
                  Enum.map(1..best_of, fn n ->
                    case Map.get(sets_by_number, n) do
                      nil -> "–"
                      s -> if is_nil(s.score2), do: "–", else: to_string(s.score2)
                    end
                  end) %>
                <% sw1 =
                  Enum.count(sorted_sets, fn s ->
                    not is_nil(s.score1) and not is_nil(s.score2) and s.score1 > s.score2
                  end) %>
                <% sw2 =
                  Enum.count(sorted_sets, fn s ->
                    not is_nil(s.score1) and not is_nil(s.score2) and s.score2 > s.score1
                  end) %>
                <% p1_won =
                  not is_nil(match.winner_registration_id) and
                    match.winner_registration_id == match.registration1_id %>
                <% p2_won =
                  not is_nil(match.winner_registration_id) and
                    match.winner_registration_id == match.registration2_id %>

                <%!-- Card header --%>
                <div class="flex items-start justify-between p-4 pb-3">
                  <div>
                    <p class="text-sm font-semibold text-white">{group.name}</p>
                    <p :if={match.scheduled_at} class="mt-0.5 text-xs text-gray-400">
                      {Calendar.strftime(match.scheduled_at, "%d/%m %H:%M")}
                    </p>
                  </div>
                  <div :if={sorted_sets != []} class="text-xl font-bold text-indigo-400">
                    {sw1}–{sw2}
                  </div>
                </div>

                <%!-- Divider --%>
                <div class="mx-4 h-px bg-indigo-500/40"></div>

                <%!-- Player rows --%>
                <div class="space-y-2 p-4 pt-3">
                  <div class="flex items-center gap-2">
                    <.icon
                      :if={p1_won}
                      name="hero-check"
                      class="size-3.5 shrink-0 text-green-400"
                    />
                    <span :if={!p1_won} class="size-3.5 shrink-0"></span>
                    <span class={[
                      "min-w-0 flex-1 truncate text-sm",
                      if(p1_won, do: "font-semibold text-white", else: "text-gray-300")
                    ]}>
                      {match_player_name(match.registration1)}
                    </span>
                    <span
                      :if={sorted_sets != []}
                      class="w-5 shrink-0 text-center text-sm font-bold text-white"
                    >
                      {sw1}
                    </span>
                    <div class="flex gap-1">
                      <span
                        :for={score <- p1_scores}
                        class="w-7 text-center text-xs tabular-nums text-gray-400"
                      >
                        {score}
                      </span>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <.icon
                      :if={p2_won}
                      name="hero-check"
                      class="size-3.5 shrink-0 text-green-400"
                    />
                    <span :if={!p2_won} class="size-3.5 shrink-0"></span>
                    <span class={[
                      "min-w-0 flex-1 truncate text-sm",
                      if(p2_won, do: "font-semibold text-white", else: "text-gray-300")
                    ]}>
                      {match_player_name(match.registration2)}
                    </span>
                    <span
                      :if={sorted_sets != []}
                      class="w-5 shrink-0 text-center text-sm font-bold text-white"
                    >
                      {sw2}
                    </span>
                    <div class="flex gap-1">
                      <span
                        :for={score <- p2_scores}
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
                    phx-click="open_edit_match"
                    phx-value-id={match.id}
                    class="text-xs text-indigo-400 hover:text-indigo-300"
                  >
                    {gettext("Edit")}
                  </button>
                  <button
                    phx-click="open_score_modal"
                    phx-value-id={match.id}
                    class="text-xs text-indigo-400 hover:text-indigo-300"
                  >
                    {gettext("Scores")}
                  </button>
                  <button
                    phx-click="delete_match"
                    phx-value-id={match.id}
                    data-confirm={gettext("Are you sure?")}
                    class="text-xs text-red-400 hover:text-red-300"
                  >
                    {gettext("Delete")}
                  </button>
                </div>
              </div>
            </div>
          </div>

          <p :if={!@active_category} class="text-gray-400 text-sm">
            {gettext("No category selected.")}
          </p>
        </div>

        <%!-- Other tabs: placeholder --%>
        <div :if={@current_tab not in ["overview", "groups", "matches"]}>
          <p class="text-gray-400 text-sm">{gettext("Coming soon.")}</p>
        </div>

        <%!-- Registration modal --%>
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
                <.input
                  field={@group_form[:best_of]}
                  type="number"
                  label={gettext("Best of")}
                />
                <.input
                  field={@group_form[:points_per_set]}
                  type="number"
                  label={gettext("Points per set")}
                />
                <input type="hidden" name="group[event_id]" value={@event.id} />
                <input
                  type="hidden"
                  name="group[category_id]"
                  value={@active_category && @active_category.id}
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
                <.input
                  field={@match_form[:best_of]}
                  type="number"
                  label={gettext("Best of")}
                />
                <.input
                  field={@match_form[:points_per_set]}
                  type="number"
                  label={gettext("Points per set")}
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
              <% {sm_match, sm_group} = @score_modal %>
              <% sm_best_of = sm_match.best_of || sm_group.best_of %>
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
                    {match_player_name(sm_match.registration1)}
                  </span>
                  <span class="w-4 shrink-0 text-center text-gray-600">vs</span>
                  <span class="flex-1 truncate text-center font-medium">
                    {match_player_name(sm_match.registration2)}
                  </span>
                </div>
                <%!-- Set rows --%>
                <div :for={n <- 1..sm_best_of} class="mb-1.5 flex items-center gap-2">
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
                </div>
                <%!-- Winner --%>
                <div class="mt-3">
                  <label class="mb-1 block text-sm font-medium text-gray-300">
                    {gettext("Winner")}
                  </label>
                  <select
                    name="winner_registration_id"
                    class="w-full rounded-md border border-white/10 bg-gray-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  >
                    <option value="">{gettext("No winner yet")}</option>
                    <option
                      :if={sm_match.registration1}
                      value={sm_match.registration1_id}
                      selected={sm_match.winner_registration_id == sm_match.registration1_id}
                    >
                      {match_player_name(sm_match.registration1)}
                    </option>
                    <option
                      :if={sm_match.registration2}
                      value={sm_match.registration2_id}
                      selected={sm_match.winner_registration_id == sm_match.registration2_id}
                    >
                      {match_player_name(sm_match.registration2)}
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
      socket
      |> load_registrations(tab, event, active_category)
      |> load_groups(tab, event, active_category)

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
         |> reload_groups_with_standings()
         |> assign(group_modal: nil, group_form: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :group_form, to_form(changeset))}
    end
  end

  def handle_event("delete_group", %{"id" => id}, socket) do
    group = Matches.get_group!(id)
    {:ok, _} = Matches.delete_group(socket.assigns.current_scope, group)
    {:noreply, reload_groups_with_standings(socket)}
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
     |> reload_groups_with_standings()}
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
     |> reload_groups_with_standings()}
  end

  def handle_event("generate_matches", _params, socket) do
    {:ok, _count} =
      Matches.generate_group_matches(socket.assigns.current_scope, socket.assigns.players_modal)

    {:noreply, reload_groups_with_standings(socket)}
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
         |> reload_groups_with_standings()
         |> assign(match_modal: nil, match_form: nil, match_group: nil, match_group_regs: [])}

      {:error, changeset} ->
        {:noreply, assign(socket, :match_form, to_form(changeset))}
    end
  end

  def handle_event("delete_match", %{"id" => id}, socket) do
    match = Matches.get_match!(id)
    {:ok, _} = Matches.delete_match(socket.assigns.current_scope, match)
    {:noreply, reload_groups_with_standings(socket)}
  end

  # Score management (superuser only)

  def handle_event("open_score_modal", %{"id" => id}, socket) do
    match_id = String.to_integer(id)

    {match, group} =
      Enum.find_value(socket.assigns.groups_with_standings, fn {g, _} ->
        case Enum.find(g.matches, &(&1.id == match_id)) do
          nil -> nil
          match -> {match, g}
        end
      end)

    {:noreply, assign(socket, :score_modal, {match, group})}
  end

  def handle_event("close_score_modal", _params, socket) do
    {:noreply, assign(socket, :score_modal, nil)}
  end

  def handle_event("save_scores", params, socket) do
    {match, _group} = socket.assigns.score_modal
    scope = socket.assigns.current_scope

    filtered_sets =
      (params["sets"] || %{})
      |> Enum.reject(fn {_, s} -> s["score1"] in [nil, ""] and s["score2"] in [nil, ""] end)
      |> Map.new()

    match_attrs = %{
      "sets" => filtered_sets,
      "winner_registration_id" => params["winner_registration_id"]
    }

    case Matches.update_match(scope, match, match_attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_groups_with_standings()
         |> assign(:score_modal, nil)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save scores."))}
    end
  end

  # Private helpers

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

  defp load_groups(socket, tab, event, active_category)
       when tab in ["groups", "matches"] and not is_nil(active_category) do
    groups = Matches.list_groups_for_event_and_category(event.id, active_category.id)
    groups_with_standings = Enum.map(groups, fn g -> {g, Matches.compute_group_standings(g)} end)
    assign(socket, :groups_with_standings, groups_with_standings)
  end

  defp load_groups(socket, _tab, _event, _active_category) do
    assign(socket, :groups_with_standings, [])
  end

  defp reload_groups_with_standings(socket) do
    event = socket.assigns.event
    active_category = socket.assigns.active_category
    groups = Matches.list_groups_for_event_and_category(event.id, active_category.id)
    groups_with_standings = Enum.map(groups, fn g -> {g, Matches.compute_group_standings(g)} end)
    assign(socket, :groups_with_standings, groups_with_standings)
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

  defp format_diff(n) when n > 0, do: "+#{n}"
  defp format_diff(n), do: to_string(n)

  defp match_player_name(%{player: %{name: name}}), do: name
  defp match_player_name(_), do: gettext("TBD")
end
