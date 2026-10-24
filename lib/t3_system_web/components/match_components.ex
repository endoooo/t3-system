defmodule T3SystemWeb.MatchComponents do
  @moduledoc """
  Helpers shared by the pages that show matches (the event page and the team
  match page).
  """
  use Gettext, backend: T3SystemWeb.Gettext

  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.Stage

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
end
