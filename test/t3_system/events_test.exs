defmodule T3System.EventsTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Events
  alias T3System.Events.League

  import T3System.Factory

  alias T3System.Events.Event

  @invalid_attrs %{name: nil}

  describe "leagues" do
    test "list_leagues/0 returns all leagues" do
      league = insert(:league)
      assert Events.list_leagues() == [league]
    end

    test "get_league!/1 returns the league with given id" do
      league = insert(:league)
      assert Events.get_league!(league.id) == league
    end

    test "create_league/2 with valid data creates a league" do
      scope = Scope.for_user(insert(:superuser))

      assert {:ok, %League{} = league} = Events.create_league(scope, %{name: "some name"})
      assert league.name == "some name"
    end

    test "create_league/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Events.create_league(scope, @invalid_attrs)
    end

    test "create_league/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))

      assert_raise FunctionClauseError, fn ->
        Events.create_league(scope, %{name: "test"})
      end
    end

    test "update_league/3 with valid data updates the league" do
      scope = Scope.for_user(insert(:superuser))
      league = insert(:league)

      assert {:ok, %League{} = league} =
               Events.update_league(scope, league, %{name: "some updated name"})

      assert league.name == "some updated name"
    end

    test "update_league/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      league = insert(:league)
      assert {:error, %Ecto.Changeset{}} = Events.update_league(scope, league, @invalid_attrs)
      assert league == Events.get_league!(league.id)
    end

    test "update_league/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      league = insert(:league)

      assert_raise FunctionClauseError, fn ->
        Events.update_league(scope, league, %{name: "test"})
      end
    end

    test "delete_league/2 deletes the league" do
      scope = Scope.for_user(insert(:superuser))
      league = insert(:league)
      assert {:ok, %League{}} = Events.delete_league(scope, league)
      assert_raise Ecto.NoResultsError, fn -> Events.get_league!(league.id) end
    end

    test "delete_league/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      league = insert(:league)

      assert_raise FunctionClauseError, fn ->
        Events.delete_league(scope, league)
      end
    end

    test "change_league/1 returns a league changeset" do
      league = insert(:league)
      assert %Ecto.Changeset{} = Events.change_league(league)
    end
  end

  describe "events" do
    @invalid_attrs %{name: nil, address: nil, datetime: nil}

    test "list_events/0 returns all events" do
      event = insert(:event)
      [listed] = Events.list_events()
      assert listed.id == event.id
      assert listed.name == event.name
      assert listed.categories == []
    end

    test "get_event!/1 returns the event with given id" do
      event = insert(:event)
      fetched = Events.get_event!(event.id)
      assert fetched.id == event.id
      assert fetched.name == event.name
      assert fetched.categories == []
    end

    test "create_event/2 with valid data creates an event" do
      scope = Scope.for_user(insert(:superuser))

      valid_attrs = %{
        name: "some name",
        address: "some address",
        datetime: ~U[2026-03-06 22:01:00Z]
      }

      assert {:ok, %Event{} = event} = Events.create_event(scope, valid_attrs)
      assert event.name == "some name"
      assert event.address == "some address"
      assert event.datetime == ~U[2026-03-06 22:01:00Z]
    end

    test "create_event/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Events.create_event(scope, @invalid_attrs)
    end

    test "create_event/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))

      assert_raise FunctionClauseError, fn ->
        Events.create_event(scope, %{
          name: "test",
          address: "addr",
          datetime: ~U[2026-03-07 12:00:00Z]
        })
      end
    end

    test "update_event/3 with valid data updates the event" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)

      update_attrs = %{
        name: "some updated name",
        address: "some updated address",
        datetime: ~U[2026-03-07 22:01:00Z]
      }

      assert {:ok, %Event{} = event} = Events.update_event(scope, event, update_attrs)
      assert event.name == "some updated name"
      assert event.address == "some updated address"
      assert event.datetime == ~U[2026-03-07 22:01:00Z]
    end

    test "update_event/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      assert {:error, %Ecto.Changeset{}} = Events.update_event(scope, event, @invalid_attrs)
      fetched = Events.get_event!(event.id)
      assert fetched.id == event.id
      assert fetched.name == event.name
    end

    test "update_event/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      event = insert(:event)

      assert_raise FunctionClauseError, fn ->
        Events.update_event(scope, event, %{name: "test"})
      end
    end

    test "delete_event/2 deletes the event" do
      scope = Scope.for_user(insert(:superuser))
      event = insert(:event)
      assert {:ok, %Event{}} = Events.delete_event(scope, event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end

    test "delete_event/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      event = insert(:event)

      assert_raise FunctionClauseError, fn ->
        Events.delete_event(scope, event)
      end
    end

    test "change_event/1 returns an event changeset" do
      event = insert(:event)
      assert %Ecto.Changeset{} = Events.change_event(event)
    end
  end

  describe "event categories" do
    test "create_event/2 with categories associates them" do
      scope = Scope.for_user(insert(:superuser))
      category = insert(:category)

      attrs = %{
        "name" => "some name",
        "address" => "some address",
        "datetime" => "2026-03-06T22:01:00Z",
        "category_ids" => [to_string(category.id)]
      }

      assert {:ok, %Event{} = event} = Events.create_event(scope, attrs)
      assert [fetched_category] = event.categories
      assert fetched_category.id == category.id
    end

    test "create_event/2 without categories creates event with no categories" do
      scope = Scope.for_user(insert(:superuser))

      attrs = %{
        "name" => "some name",
        "address" => "some address",
        "datetime" => "2026-03-06T22:01:00Z"
      }

      assert {:ok, %Event{} = event} = Events.create_event(scope, attrs)
      assert event.categories == []
    end

    test "update_event/3 replaces categories" do
      scope = Scope.for_user(insert(:superuser))
      category1 = insert(:category)
      category2 = insert(:category)
      event = insert(:event)

      attrs = %{"category_ids" => [to_string(category1.id)]}
      {:ok, event} = Events.update_event(scope, event, attrs)
      assert [c] = event.categories
      assert c.id == category1.id

      attrs2 = %{"category_ids" => [to_string(category2.id)]}
      {:ok, event} = Events.update_event(scope, event, attrs2)
      assert [c] = event.categories
      assert c.id == category2.id
    end

    test "update_event/3 with empty category_ids clears categories" do
      scope = Scope.for_user(insert(:superuser))
      category = insert(:category)
      event = insert(:event)

      {:ok, event} =
        Events.update_event(scope, event, %{"category_ids" => [to_string(category.id)]})

      assert length(event.categories) == 1

      {:ok, event} = Events.update_event(scope, event, %{"category_ids" => [""]})
      assert event.categories == []
    end
  end
end
