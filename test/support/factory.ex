defmodule T3System.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: T3System.Repo

  alias T3System.Accounts.User
  alias T3System.Categories.Category
  alias T3System.Clubs.Club
  alias T3System.Events.Event
  alias T3System.Events.League
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.MatchPlayer
  alias T3System.Matches.MatchSet
  alias T3System.Matches.Stage
  alias T3System.Players.Player
  alias T3System.Registrations.Registration
  alias T3System.Registrations.RegistrationPlayer
  alias T3System.Tables.Table

  def user_factory do
    %User{
      email: sequence(:email, &"user#{&1}@example.com"),
      role: "user",
      confirmed_at: DateTime.utc_now(:second)
    }
  end

  def superuser_factory do
    struct!(
      user_factory(),
      email: sequence(:email, &"superuser#{&1}@example.com"),
      role: "superuser"
    )
  end

  def league_factory do
    %League{
      name: sequence(:name, &"League #{&1}")
    }
  end

  def event_factory do
    %Event{
      name: sequence(:name, &"Event #{&1}"),
      address: sequence(:address, &"Address #{&1}"),
      datetime: ~U[2026-03-07 12:00:00Z]
    }
  end

  def category_factory do
    %Category{
      name: sequence(:name, &"Category #{&1}")
    }
  end

  def club_factory do
    %Club{
      name: sequence(:name, &"Club #{&1}")
    }
  end

  def player_factory do
    %Player{
      name: sequence(:name, &"Player #{&1}"),
      birthdate: ~D[2026-03-06],
      picture_url: "https://example.com/player.jpg"
    }
  end

  # Singles by default: one registration player. Pass your own list with
  # `registration_players: [build(:registration_player, player: p, club: c)]`.
  # Each row's event and category are copied from the registration by the DB.
  def registration_factory do
    %Registration{
      event: build(:event),
      category: build(:category),
      registration_players: [build(:registration_player)]
    }
  end

  # A pair in a doubles category: two different players, each with their own
  # club. `insert(:doubles_registration, event: e, category: c)` with `c` a
  # doubles category, or pass your own `registration_players`.
  def doubles_registration_factory do
    %Registration{
      event: build(:event),
      category: build(:category, format: "doubles"),
      registration_players: [
        build(:registration_player, position: 1),
        build(:registration_player, position: 2)
      ]
    }
  end

  def team_category_factory do
    struct!(category_factory(), format: "team")
  end

  # A team in a team category: a name and three different players, each with
  # their own club. `insert(:team, event: e, category: c)` with `c` a team
  # category, or pass your own `registration_players`.
  def team_factory do
    %Registration{
      name: sequence(:team_name, &"Team #{&1}"),
      event: build(:event),
      category: build(:team_category),
      registration_players:
        for(position <- 1..3, do: build(:registration_player, position: position))
    }
  end

  def registration_player_factory do
    %RegistrationPlayer{
      player: build(:player),
      club: build(:club),
      position: 1
    }
  end

  def stage_factory do
    %Stage{
      name: sequence(:name, &"Stage #{&1}"),
      type: "group",
      order: 1,
      event: build(:event),
      category: build(:category)
    }
  end

  def group_factory do
    %Group{
      name: sequence(:name, &"Group #{&1}"),
      stage: build(:stage)
    }
  end

  def table_factory do
    %Table{
      name: sequence(:name, &"Table #{&1}"),
      event: build(:event)
    }
  end

  def match_factory do
    stage = build(:stage)

    %Match{
      event: stage.event,
      group: build(:group, stage: stage)
    }
  end

  # A team match: a match between two teams in a team category's group. Pass
  # `event:`, `group:` and the teams (`registration1:`, `registration2:`) to
  # place it in your own event.
  def team_match_factory do
    event = build(:event)
    category = build(:team_category)
    stage = build(:stage, event: event, category: category)

    %Match{
      event: event,
      group: build(:group, stage: stage),
      registration1: build(:team, event: event, category: category),
      registration2: build(:team, event: event, category: category)
    }
  end

  # A match inside a team match: pass `team_match:` (with its teams and their
  # players loaded, e.g. an inserted `:team_match`). Copies the event and teams
  # from it; `players1:`/`players2:` are each side's player ids (defaults to
  # each team's first player, a singles match).
  def inner_match_factory(attrs) do
    {team_match, attrs} = Map.pop!(attrs, :team_match)
    {players1, attrs} = Map.pop(attrs, :players1, first_player_ids(team_match.registration1))
    {players2, attrs} = Map.pop(attrs, :players2, first_player_ids(team_match.registration2))

    match_players =
      Enum.map(players1, &%MatchPlayer{side: 1, player_id: &1}) ++
        Enum.map(players2, &%MatchPlayer{side: 2, player_id: &1})

    %Match{
      event_id: team_match.event_id,
      team_match_id: team_match.id,
      registration1_id: team_match.registration1_id,
      registration2_id: team_match.registration2_id,
      match_players: match_players
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  defp first_player_ids(%Registration{registration_players: [first | _]}),
    do: [first.player_id]

  def match_set_factory do
    %MatchSet{
      match: build(:match),
      set_number: 1,
      score1: 11,
      score2: 7
    }
  end
end
