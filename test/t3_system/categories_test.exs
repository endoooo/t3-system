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

  describe "category format" do
    test "create_category/2 defaults the format to singles" do
      scope = Scope.for_user(insert(:superuser))

      assert {:ok, %Category{format: "singles"}} =
               Categories.create_category(scope, %{name: "Livre"})
    end

    test "create_category/2 creates a doubles category" do
      scope = Scope.for_user(insert(:superuser))

      assert {:ok, %Category{format: "doubles"}} =
               Categories.create_category(scope, %{name: "Duplas Livre", format: "doubles"})
    end

    test "create_category/2 rejects an unknown format" do
      scope = Scope.for_user(insert(:superuser))

      assert {:error, changeset} =
               Categories.create_category(scope, %{name: "Trios", format: "trios"})

      assert %{format: ["is invalid"]} = errors_on(changeset)
    end

    test "create_category/2 rejects a blank format" do
      scope = Scope.for_user(insert(:superuser))

      assert {:error, changeset} =
               Categories.create_category(scope, %{name: "Livre", format: nil})

      assert %{format: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_category/3 changes the format while the category has no registrations" do
      scope = Scope.for_user(insert(:superuser))
      category = insert(:category)

      assert {:ok, %Category{format: "doubles"}} =
               Categories.update_category(scope, category, %{format: "doubles"})
    end

    test "update_category/3 rejects a format change once the category has a registration" do
      scope = Scope.for_user(insert(:superuser))
      category = insert(:category)
      insert(:registration, category: category)

      assert {:error, changeset} =
               Categories.update_category(scope, category, %{format: "doubles"})

      assert %{format: [_message]} = errors_on(changeset)
      assert Categories.get_category!(category.id).format == "singles"
    end

    test "update_category/3 still renames a category that has registrations" do
      scope = Scope.for_user(insert(:superuser))
      category = insert(:category)
      insert(:registration, category: category)

      assert {:ok, %Category{name: "Renamed", format: "singles"}} =
               Categories.update_category(scope, category, %{name: "Renamed", format: "singles"})
    end

    test "format_locked?/1 is true only once the category has a registration in any event" do
      category = insert(:category)
      refute Categories.format_locked?(category)

      insert(:registration, category: category)
      assert Categories.format_locked?(category)
    end
  end
end
