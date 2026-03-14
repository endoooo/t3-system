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
      assert %T3System.Players.Player{} = result.player
      assert %T3System.Events.Event{} = result.event
      assert %T3System.Clubs.Club{} = result.club
    end

    test "get_registration!/1 returns the registration with given id" do
      registration = insert(:registration)
      result = Registrations.get_registration!(registration.id)
      assert result.id == registration.id
      assert %T3System.Players.Player{} = result.player
      assert %T3System.Events.Event{} = result.event
      assert %T3System.Clubs.Club{} = result.club
    end

    test "get_registration!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn -> Registrations.get_registration!(0) end
    end

    test "create_registration/2 with valid data creates a registration" do
      scope = Scope.for_user(insert(:superuser))
      player = insert(:player)
      event = insert(:event)
      club = insert(:club)

      valid_attrs = %{player_id: player.id, event_id: event.id, club_id: club.id}

      assert {:ok, %Registration{} = registration} =
               Registrations.create_registration(scope, valid_attrs)

      assert registration.player_id == player.id
      assert registration.event_id == event.id
      assert registration.club_id == club.id
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
          player_id: player.id,
          event_id: event.id,
          club_id: club.id
        })
      end
    end

    test "create_registration/2 fails on duplicate player+event" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)

      attrs = %{
        player_id: registration.player_id,
        event_id: registration.event_id,
        club_id: registration.club_id
      }

      assert {:error, %Ecto.Changeset{}} = Registrations.create_registration(scope, attrs)
    end

    test "update_registration/3 with valid data updates the registration" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)
      new_club = insert(:club)

      assert {:ok, %Registration{} = updated} =
               Registrations.update_registration(scope, registration, %{club_id: new_club.id})

      assert updated.club_id == new_club.id
    end

    test "update_registration/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      registration = insert(:registration)

      assert {:error, %Ecto.Changeset{}} =
               Registrations.update_registration(scope, registration, %{player_id: nil})
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
