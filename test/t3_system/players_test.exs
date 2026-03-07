defmodule T3System.PlayersTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Players
  alias T3System.Players.Player

  import T3System.Factory

  @invalid_attrs %{name: nil, birthdate: nil, picture_url: nil}

  describe "player" do
    test "list_player/0 returns all player" do
      player = insert(:player)
      assert Players.list_player() == [player]
    end

    test "get_player!/1 returns the player with given id" do
      player = insert(:player)
      assert Players.get_player!(player.id) == player
    end

    test "create_player/2 with valid data creates a player" do
      scope = Scope.for_user(insert(:superuser))

      valid_attrs = %{
        name: "some name",
        birthdate: ~D[2026-03-06],
        picture_url: "some picture_url"
      }

      assert {:ok, %Player{} = player} = Players.create_player(scope, valid_attrs)
      assert player.name == "some name"
      assert player.birthdate == ~D[2026-03-06]
      assert player.picture_url == "some picture_url"
    end

    test "create_player/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Players.create_player(scope, @invalid_attrs)
    end

    test "create_player/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))

      assert_raise FunctionClauseError, fn ->
        Players.create_player(scope, %{name: "test", birthdate: ~D[2026-03-06]})
      end
    end

    test "update_player/3 with valid data updates the player" do
      scope = Scope.for_user(insert(:superuser))
      player = insert(:player)

      update_attrs = %{
        name: "some updated name",
        birthdate: ~D[2026-03-07],
        picture_url: "some updated picture_url"
      }

      assert {:ok, %Player{} = player} = Players.update_player(scope, player, update_attrs)
      assert player.name == "some updated name"
      assert player.birthdate == ~D[2026-03-07]
      assert player.picture_url == "some updated picture_url"
    end

    test "update_player/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      player = insert(:player)
      assert {:error, %Ecto.Changeset{}} = Players.update_player(scope, player, @invalid_attrs)
      assert player == Players.get_player!(player.id)
    end

    test "update_player/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      player = insert(:player)

      assert_raise FunctionClauseError, fn ->
        Players.update_player(scope, player, %{name: "test"})
      end
    end

    test "delete_player/2 deletes the player" do
      scope = Scope.for_user(insert(:superuser))
      player = insert(:player)
      assert {:ok, %Player{}} = Players.delete_player(scope, player)
      assert_raise Ecto.NoResultsError, fn -> Players.get_player!(player.id) end
    end

    test "delete_player/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      player = insert(:player)

      assert_raise FunctionClauseError, fn ->
        Players.delete_player(scope, player)
      end
    end

    test "change_player/1 returns a player changeset" do
      player = insert(:player)
      assert %Ecto.Changeset{} = Players.change_player(player)
    end
  end
end
