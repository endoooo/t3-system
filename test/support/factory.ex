defmodule T3System.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: T3System.Repo

  alias T3System.Accounts.User
  alias T3System.Categories.Category
  alias T3System.Events.Event
  alias T3System.Events.League
  alias T3System.Players.Player

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

  def player_factory do
    %Player{
      name: sequence(:name, &"Player #{&1}"),
      birthdate: ~D[2026-03-06],
      picture_url: "https://example.com/player.jpg"
    }
  end
end
