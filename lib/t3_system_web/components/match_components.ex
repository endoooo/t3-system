defmodule T3SystemWeb.MatchComponents do
  @moduledoc """
  Components and helpers shared by the pages that show matches (the event page
  and the team match page): the match card and match labels. The score modal
  is `T3SystemWeb.ScoreModalComponent`.
  """
  use Phoenix.Component
  use Gettext, backend: T3SystemWeb.Gettext

  import T3SystemWeb.CoreComponents,
    only: [button: 1, card: 1, icon: 1, tooltip: 1]

  import T3SystemWeb.PlayerComponents, only: [player_names: 1, player_short_names: 1]

  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.Stage
  alias T3System.Registrations.Registration

  @doc """
  A bracket round's name, counted from the final: "Final", "Semis",
  "Quartas"... (e.g. round 2 of 3 is "Semis").
  """
  @spec round_label(pos_integer(), pos_integer()) :: String.t()
  def round_label(round, total_rounds) do
    case total_rounds - round do
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

  @doc """
  Where a match is played, from its preloaded group (with stage) or bracket
  stage: "Grupos · Grupo A", "Mata-mata · Semis".
  """
  @spec stage_label(Match.t()) :: String.t()
  def stage_label(%Match{group: %Group{stage: %Stage{} = stage} = group}),
    do: "#{stage.name} · #{group.name}"

  def stage_label(%Match{stage: %Stage{rounds: rounds} = stage, round: round})
      when is_integer(rounds) and is_integer(round),
      do: "#{stage.name} · #{round_label(round, rounds)}"

  def stage_label(%Match{stage: %Stage{} = stage}), do: stage.name

  @doc """
  A match inside a team match, in its team match's context: the team names
  and its position labels, "AABB A x Clube Y · AB x XY". Needs the team match
  (with its teams) preloaded.
  """
  @spec team_match_context(Match.t()) :: String.t()
  def team_match_context(%Match{team_match: %Match{} = team_match} = match) do
    teams = "#{team_label(team_match.registration1)} x #{team_label(team_match.registration2)}"

    if blank?(match.position1) and blank?(match.position2),
      do: teams,
      else: "#{teams} · #{match.position1} x #{match.position2}"
  end

  defp team_label(%Registration{name: name}), do: name
  defp team_label(_registration), do: gettext("TBD")

  defp blank?(value), do: value in [nil, ""]

  @doc """
  The players of one side (1 or 2) of a match inside a team match, from its
  preloaded match players: short (`:short`) or full (`:full`) names.
  """
  @spec match_side_names(Match.t(), 1 | 2, :short | :full) :: String.t()
  def match_side_names(%Match{match_players: players}, side, format) do
    case Enum.filter(players, &(&1.side == side)) do
      [] -> gettext("TBD")
      side_players when format == :short -> player_short_names(side_players)
      side_players -> player_names(side_players)
    end
  end

  @doc """
  The `match_card/1` data of a match inside a team match (sets, table and
  match players preloaded): position labels and each side's players. `fields`
  names the card (`:label`, ...) like in `match_card_data/2`.
  """
  @spec inner_match_card_data(Match.t(), map() | keyword()) :: map()
  def inner_match_card_data(%Match{} = match, fields) do
    match_card_data(
      match,
      Map.merge(
        %{
          p1_position: match.position1,
          p2_position: match.position2,
          p1_name: match_side_names(match, 1, :short),
          p2_name: match_side_names(match, 2, :short),
          p1_full_name: match_side_names(match, 1, :full),
          p2_full_name: match_side_names(match, 2, :full)
        },
        Map.new(fields)
      )
    )
  end

  @doc """
  The data `match_card/1` renders, from a match with its sets and table
  preloaded. `fields` names the card (`:label`, `:p1_name`, `:p2_name`,
  `:p1_full_name`, `:p2_full_name`, optional `:p1_position`/`:p2_position`
  and `:label_navigate`, a path that turns the label into a link) and may add
  keys the caller needs (e.g. a sort key).
  """
  @spec match_card_data(Match.t(), map() | keyword()) :: map()
  def match_card_data(%Match{} = match, fields) do
    sets = sort_sets(match.sets)
    winner_id = match.winner_registration_id

    Map.merge(
      %{
        id: match.id,
        kind: :match,
        scheduled_at: match.scheduled_at,
        table: loaded(match.table),
        table_position: match.table_position,
        is_bye: match.is_bye,
        finished: not is_nil(winner_id),
        ongoing: match.is_ongoing,
        has_sets: sets != [],
        p1_scores: Enum.map(sets, &format_set_score(&1.score1)),
        p2_scores: Enum.map(sets, &format_set_score(&1.score2)),
        sw1: Enum.count(sets, &(&1.winner_registration_id == match.registration1_id)),
        sw2: Enum.count(sets, &(&1.winner_registration_id == match.registration2_id)),
        p1_won: not is_nil(winner_id) and winner_id == match.registration1_id,
        p2_won: not is_nil(winner_id) and winner_id == match.registration2_id,
        p1_position: nil,
        p2_position: nil,
        label_navigate: nil
      },
      Map.new(fields)
    )
  end

  defp loaded(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded(value), do: value

  defp sort_sets(%Ecto.Association.NotLoaded{}), do: []
  defp sort_sets(sets), do: Enum.sort_by(sets, & &1.set_number)

  defp format_set_score(nil), do: "–"
  defp format_set_score(score), do: to_string(score)

  @doc """
  A match card: header (label, time, table, set score), one row per side
  (position label, names, set scores) and a footer with the category and the
  superuser actions ("Resultados", and "Editar" when `edit_event` is given).
  """
  attr :card, :map, required: true, doc: "built with `match_card_data/2`"
  attr :is_superuser, :boolean, required: true
  attr :show_category, :boolean, default: false
  attr :edit_event, :string, default: nil, doc: "event sent by the \"Editar\" button"

  def match_card(assigns) do
    ~H"""
    <.card id={"match-#{@card.id}"} padded={false}>
      <%!-- Card header --%>
      <div class="flex items-center gap-4 border-b border-border px-4 py-2.5">
        <.ongoing_dot :if={@card.ongoing} class="-mr-2" />
        <p class="min-w-0 flex-1 truncate font-display text-sm font-bold text-fg-muted">
          <.link
            :if={@card.label_navigate}
            navigate={@card.label_navigate}
            class="hover:text-fg hover:underline"
          >
            {@card.label}
          </.link>
          <span :if={!@card.label_navigate}>{@card.label}</span>
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
          id={"tooltip-match-#{@card.id}-1"}
          position={@card.p1_position}
          name={@card.p1_name}
          full_name={@card.p1_full_name}
          won={@card.p1_won}
          has_sets={@card.has_sets}
          set_wins={@card.sw1}
          scores={@card.p1_scores}
        />
        <.match_card_row
          id={"tooltip-match-#{@card.id}-2"}
          position={@card.p2_position}
          name={@card.p2_name}
          full_name={@card.p2_full_name}
          won={@card.p2_won}
          has_sets={@card.has_sets}
          set_wins={@card.sw2}
          scores={@card.p2_scores}
        />
      </div>

      <%!-- Footer: category and superuser actions --%>
      <div
        :if={@is_superuser || @show_category}
        class="flex min-h-11 items-center justify-between gap-2 border-t border-border px-2 py-1.5"
      >
        <p :if={@show_category} class="min-w-0 truncate px-2 text-xs text-fg-muted">
          {@card.category_name}
        </p>
        <div :if={@is_superuser} class="ml-auto flex gap-1">
          <.button
            :if={@edit_event}
            variant="ghost"
            size="sm"
            phx-click={@edit_event}
            phx-value-id={@card.id}
          >
            {gettext("Editar")}
          </.button>
          <.button variant="ghost" size="sm" phx-click="open_score_modal" phx-value-id={@card.id}>
            {gettext("Resultados")}
          </.button>
        </div>
      </div>
    </.card>
    """
  end

  @doc """
  One side of a match card: an optional position label, the (short) names
  with the full names in a tooltip, the sets won and each set's score.
  """
  attr :id, :string, required: true
  attr :position, :string, default: nil, doc: "position label shown before the names"
  attr :name, :string, required: true
  attr :full_name, :string, required: true, doc: "shown in the tooltip"
  attr :won, :boolean, required: true
  attr :has_sets, :boolean, required: true
  attr :set_wins, :integer, required: true
  attr :scores, :list, required: true

  def match_card_row(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class="flex min-w-0 flex-1 items-center gap-2">
        <span
          :if={@position not in [nil, ""]}
          class="shrink-0 text-xs font-bold whitespace-nowrap text-fg-muted"
        >
          {@position}
        </span>
        <.tooltip
          id={@id}
          text={@full_name}
          class={["min-w-0 truncate text-sm", @won && "font-bold"]}
        >
          {@name}
        </.tooltip>
        <.icon :if={@won} name="hero-check-micro" class="shrink-0 text-primary" />
      </div>
      <span :if={@has_sets} class="w-5 shrink-0 text-center text-sm font-bold tabular-nums">
        {@set_wins}
      </span>
      <div class="flex shrink-0 gap-1">
        <span :for={score <- @scores} class="w-7 text-center text-xs text-fg-muted tabular-nums">
          {score}
        </span>
      </div>
    </div>
    """
  end

  @doc "A pulsing dot marking an ongoing match."
  attr :class, :any, default: nil

  def ongoing_dot(assigns) do
    ~H"""
    <span class={["relative flex size-2 shrink-0", @class]} title={gettext("Em andamento")}>
      <span class="absolute inline-flex size-full animate-ping rounded-full bg-primary opacity-75">
      </span>
      <span class="relative inline-flex size-2 rounded-full bg-primary"></span>
      <span class="sr-only">{gettext("Em andamento")}</span>
    </span>
    """
  end
end
