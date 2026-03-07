defmodule T3System.EventsTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Events
  alias T3System.Events.League

  import T3System.Factory

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
end
