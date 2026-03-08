defmodule T3System.CategoriesTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Categories
  alias T3System.Categories.Category

  import T3System.Factory

  @invalid_attrs %{name: nil}

  describe "categories" do
    test "list_categories/0 returns all categories" do
      category = insert(:category)
      assert Categories.list_categories() == [category]
    end

    test "get_category!/1 returns the category with given id" do
      category = insert(:category)
      assert Categories.get_category!(category.id) == category
    end

    test "create_category/2 with valid data creates a category" do
      scope = Scope.for_user(insert(:superuser))
      valid_attrs = %{name: "some name"}

      assert {:ok, %Category{} = category} = Categories.create_category(scope, valid_attrs)
      assert category.name == "some name"
    end

    test "create_category/2 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      assert {:error, %Ecto.Changeset{}} = Categories.create_category(scope, @invalid_attrs)
    end

    test "create_category/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))

      assert_raise FunctionClauseError, fn ->
        Categories.create_category(scope, %{name: "test"})
      end
    end

    test "update_category/3 with valid data updates the category" do
      scope = Scope.for_user(insert(:superuser))
      category = insert(:category)
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Category{} = category} =
               Categories.update_category(scope, category, update_attrs)

      assert category.name == "some updated name"
    end

    test "update_category/3 with invalid data returns error changeset" do
      scope = Scope.for_user(insert(:superuser))
      category = insert(:category)

      assert {:error, %Ecto.Changeset{}} =
               Categories.update_category(scope, category, @invalid_attrs)

      assert category == Categories.get_category!(category.id)
    end

    test "update_category/3 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      category = insert(:category)

      assert_raise FunctionClauseError, fn ->
        Categories.update_category(scope, category, %{name: "test"})
      end
    end

    test "delete_category/2 deletes the category" do
      scope = Scope.for_user(insert(:superuser))
      category = insert(:category)
      assert {:ok, %Category{}} = Categories.delete_category(scope, category)
      assert_raise Ecto.NoResultsError, fn -> Categories.get_category!(category.id) end
    end

    test "delete_category/2 with non-superuser scope raises" do
      scope = Scope.for_user(insert(:user))
      category = insert(:category)

      assert_raise FunctionClauseError, fn ->
        Categories.delete_category(scope, category)
      end
    end

    test "change_category/1 returns a category changeset" do
      category = insert(:category)
      assert %Ecto.Changeset{} = Categories.change_category(category)
    end
  end
end
