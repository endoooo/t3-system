defmodule T3System.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: T3System.Repo

  alias T3System.Accounts.User
  alias T3System.Categories.Category
  alias T3System.Clubs.Club
  alias T3System.Events.Event
  alias T3System.Events.League
  alias T3System.Matches.Bracket
  alias T3System.Matches.Group
  alias T3System.Matches.Match
  alias T3System.Matches.MatchSet
  alias T3System.Players.Player
  alias T3System.Registrations.Registration

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

  def registration_factory do
    %Registration{
      player: build(:player),
      event: build(:event),
      club: build(:club),
      category: build(:category)
    }
  end

  def group_factory do
    %Group{
      name: sequence(:name, &"Group #{&1}"),
      event: build(:event)
    }
  end

  def bracket_factory do
    %Bracket{
      name: sequence(:name, &"Bracket #{&1}"),
      event: build(:event)
    }
  end

  def match_factory do
    %Match{
      event: build(:event),
      group: build(:group)
    }
  end

  def match_set_factory do
    %MatchSet{
      match: build(:match),
      set_number: 1,
      score1: 11,
      score2: 7
    }
  end
end
