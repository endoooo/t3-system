defmodule T3System.RegistrationsTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Registrations
  alias T3System.Registrations.Registration

  import T3System.Factory

  describe "registrations" do
    test "list_registrations/0 returns all registrations with preloads" do
      registration = insert(:registration)
      [result] = Registrations.list_registrations()
      assert result.id == registration.id

      assert [%{player: %T3System.Players.Player{}, club: %T3System.Clubs.Club{}}] =
               result.registration_players

      assert %T3System.Events.Event{} = result.event
    end

    test "get_registration!/1 returns the registration with given id" do
      registration = insert(:registration)
      result = Registrations.get_registration!(registration.id)
      assert result.id == registration.id

      assert [%{player: %T3System.Players.Player{}, club: %T3System.Clubs.Club{}}] =
               result.registration_players

      assert %T3System.Events.Event{} = result.event
    end

    test "get_registration!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn -> Registrations.get_registration!(0) end
    end

    test "create_registration/2 with nested players creates a registration" do
      scope = Scope.for_user(insert(:superuser))
      player = insert(:player)
      event = insert(:event)
      club = insert(:club)
      category = insert(:category)

      valid_attrs = %{
        event_id: event.id,
        category_id: category.id,
        registration_players: [%{player_id: player.id, club_id: club.id, position: 1}]
      }

      assert {:ok, %Registration{} = registration} =
               Registrations.create_registration(scope, valid_attrs)

      registration = Registrations.get_registration!(registration.id)
      assert registration.event_id == event.id
      assert registration.category_id == category.id

      assert [%{player: %{id: player_id}, club: %{id: club_id}}] =
               registration.registration_players

      assert {player_id, club_id} == {player.id, club.id}
    end

    test "create_registration/2 without players returns error changeset" do
      scope = Scope.for_user(insert(:superuser))

      assert {:error, changeset} =
               Registrations.create_registration(scope, %{
                 event_id: insert(:event).id,
                 category_id: insert(:category).id,
                 registration_players: []
               })

      assert %{registration_players: [_]} = errors_on(changeset)
    end

    test "create_registration/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Registrations.create_registration(scope, %{})
    end

    test "create_registration/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      player = insert(:player)
      event = insert(:event)
      club = insert(:club)

      assert_raise FunctionClauseError, fn ->
        Registrations.create_registration(scope, %{
          event_id: event.id,
          registration_players: [%{player_id: player.id, club_id: club.id, position: 1}]
        })
      end
    end

    test "create_registration/2 rejects a player already registered in the event + category" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      [taken] = registration.registration_players

      attrs = %{
        event_id: registration.event_id,
        category_id: registration.category_id,
        registration_players: [
          %{player_id: taken.player_id, club_id: insert(:club).id, position: 1}
        ]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: [%{player_id: ["already registered in this category"]}]} =
               errors_on(changeset)
    end

    test "create_registration/2 rejects a player already in position 2 of another registration" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      category = insert(:category)
      partner = insert(:player)

      insert(:registration,
        event: event,
        category: category,
        registration_players: [
          build(:registration_player, position: 1),
          build(:registration_player, player: partner, position: 2)
        ]
      )

      attrs = %{
        event_id: event.id,
        category_id: category.id,
        registration_players: [%{player_id: partner.id, club_id: insert(:club).id, position: 1}]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: [%{player_id: ["already registered in this category"]}]} =
               errors_on(changeset)
    end

    test "create_registration/2 accepts the same player in another category of the event" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      [taken] = registration.registration_players

      attrs = %{
        event_id: registration.event_id,
        category_id: insert(:category).id,
        registration_players: [%{player_id: taken.player_id, club_id: taken.club_id, position: 1}]
      }

      assert {:ok, %Registration{}} = Registrations.create_registration(scope, attrs)
    end

    test "create_registration/2 rejects a player count that doesn't match the format" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      singles = insert(:category)
      doubles = insert(:category, format: "doubles")

      rows = fn count ->
        for position <- 1..count//1 do
          %{player_id: insert(:player).id, club_id: insert(:club).id, position: position}
        end
      end

      attrs = fn category, count ->
        %{event_id: event.id, category_id: category.id, registration_players: rows.(count)}
      end

      assert {:error, changeset} = Registrations.create_registration(scope, attrs.(singles, 0))
      assert %{registration_players: [_ | _]} = errors_on(changeset)

      assert {:error, changeset} = Registrations.create_registration(scope, attrs.(singles, 2))

      assert %{registration_players: ["a singles registration must have exactly 1 player"]} =
               errors_on(changeset)

      assert {:error, changeset} = Registrations.create_registration(scope, attrs.(doubles, 1))

      assert %{registration_players: ["a doubles registration must have exactly 2 players"]} =
               errors_on(changeset)

      assert {:error, changeset} = Registrations.create_registration(scope, attrs.(doubles, 3))

      assert %{registration_players: ["a doubles registration must have exactly 2 players"]} =
               errors_on(changeset)

      assert {:ok, %Registration{}} = Registrations.create_registration(scope, attrs.(doubles, 2))
    end

    test "create_registration/2 rejects the same player twice in one pair" do
      scope = Scope.for_user(insert(:superuser))
      player = insert(:player)

      attrs = %{
        event_id: insert(:event).id,
        category_id: insert(:category, format: "doubles").id,
        registration_players: [
          %{player_id: player.id, club_id: insert(:club).id, position: 1},
          %{player_id: player.id, club_id: insert(:club).id, position: 2}
        ]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: ["a pair must have two different players"]} =
               errors_on(changeset)
    end

    test "create_registration/2 rejects a partner already in another pair of the category" do
      scope = Scope.for_user(insert(:superuser))
      existing = insert(:doubles_registration)
      [_, partner] = existing.registration_players

      attrs = %{
        event_id: existing.event_id,
        category_id: existing.category_id,
        registration_players: [
          %{player_id: insert(:player).id, club_id: insert(:club).id, position: 1},
          %{player_id: partner.player_id, club_id: insert(:club).id, position: 2}
        ]
      }

      assert {:error, changeset} = Registrations.create_registration(scope, attrs)

      assert %{registration_players: [%{}, %{player_id: ["already registered in this category"]}]} =
               errors_on(changeset)
    end

    test "create_registration/2 accepts a singles player in a doubles category of the event" do
      scope = Scope.for_user(insert(:superuser))
      singles = insert(:registration)
      [rp] = singles.registration_players

      attrs = %{
        event_id: singles.event_id,
        category_id: insert(:category, format: "doubles").id,
        registration_players: [
          %{player_id: rp.player_id, club_id: rp.club_id, position: 1},
          %{player_id: insert(:player).id, club_id: insert(:club).id, position: 2}
        ]
      }

      assert {:ok, %Registration{}} = Registrations.create_registration(scope, attrs)
    end

    test "update_registration/3 replaces the players" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      new_player = insert(:player)
      new_club = insert(:club)

      assert {:ok, %Registration{}} =
               Registrations.update_registration(scope, registration, %{
                 registration_players: [
                   %{player_id: new_player.id, club_id: new_club.id, position: 1}
                 ]
               })

      assert [%{player_id: player_id, club_id: club_id}] =
               Registrations.get_registration!(registration.id).registration_players

      assert {player_id, club_id} == {new_player.id, new_club.id}
    end

    test "update_registration/3 moving to a category where the player is taken is rejected" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      [rp] = registration.registration_players

      other =
        insert(:registration,
          event: registration.event,
          registration_players: [build(:registration_player, player: rp.player)]
        )

      assert {:error, changeset} =
               Registrations.update_registration(scope, registration, %{
                 category_id: other.category_id
               })

      assert %{category_id: ["player already registered in this category"]} =
               errors_on(changeset)
    end

    test "update_registration/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)

      assert {:error, %Ecto.Changeset{}} =
               Registrations.update_registration(scope, registration, %{registration_players: []})
    end

    test "list_registered_player_ids/2 returns players in any position" do
      event = insert(:event)
      category = insert(:category)
      [first, partner] = insert_list(2, :player)

      insert(:registration,
        event: event,
        category: category,
        registration_players: [
          build(:registration_player, player: first, position: 1),
          build(:registration_player, player: partner, position: 2)
        ]
      )

      insert(:registration, event: event)

      assert Registrations.list_registered_player_ids(event.id, category.id) ==
               MapSet.new([first.id, partner.id])
    end

    test "update_registration/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      registration = insert(:registration)

      assert_raise FunctionClauseError, fn ->
        Registrations.update_registration(scope, registration, %{})
      end
    end

    test "delete_registration/2 deletes the registration" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      assert {:ok, %Registration{}} = Registrations.delete_registration(scope, registration)
      assert_raise Ecto.NoResultsError, fn -> Registrations.get_registration!(registration.id) end
    end

    test "delete_registration/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      registration = insert(:registration)

      assert_raise FunctionClauseError, fn ->
        Registrations.delete_registration(scope, registration)
      end
    end

    test "change_registration/1 returns a registration changeset" do
      registration = insert(:registration)
      assert %Ecto.Changeset{} = Registrations.change_registration(registration)
    end
  end
end
