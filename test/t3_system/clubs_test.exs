defmodule T3System.ClubsTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Clubs
  alias T3System.Clubs.Club

  import T3System.Factory

  @invalid_attrs %{name: nil}

  describe "clubs" do
    test "list_clubs/0 returns all clubs" do
      club = insert(:club)
      assert Clubs.list_clubs() == [club]
    end

    test "get_club!/1 returns the club with given id" do
      club = insert(:club)
      assert Clubs.get_club!(club.id) == club
    end

    test "create_club/2 with valid data creates a club" do
      scope = Scope.for_user(insert(:superuser))
      valid_attrs = %{name: "some name"}

      assert {:ok, %Club{} = club} = Clubs.create_club(scope, valid_attrs)
      assert club.name == "some name"
    end

    test "create_club/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Clubs.create_club(scope, @invalid_attrs)
    end

    test "create_club/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))

      assert_raise FunctionClauseError, fn ->
        Clubs.create_club(scope, %{name: "test"})
      end
    end

    test "update_club/3 with valid data updates the club" do
      scope = Scope.for_user(insert(:superuser))
      club = insert(:club)
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Club{} = club} = Clubs.update_club(scope, club, update_attrs)
      assert club.name == "some updated name"
    end

    test "update_club/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      club = insert(:club)
      assert {:error, %Ecto.Changeset{}} = Clubs.update_club(scope, club, @invalid_attrs)
      assert club == Clubs.get_club!(club.id)
    end

    test "update_club/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      club = insert(:club)

      assert_raise FunctionClauseError, fn ->
        Clubs.update_club(scope, club, %{name: "test"})
      end
    end

    test "delete_club/2 deletes the club" do
      scope = Scope.for_user(insert(:superuser))
      club = insert(:club)
      assert {:ok, %Club{}} = Clubs.delete_club(scope, club)
      assert_raise Ecto.NoResultsError, fn -> Clubs.get_club!(club.id) end
    end

    test "delete_club/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      club = insert(:club)

      assert_raise FunctionClauseError, fn ->
        Clubs.delete_club(scope, club)
      end
    end

    test "change_club/1 returns a club changeset" do
      club = insert(:club)
      assert %Ecto.Changeset{} = Clubs.change_club(club)
    end
  end
end
