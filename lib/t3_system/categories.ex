defmodule T3System.Categories do
  @moduledoc """
  The Categories context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Categories.Category

  @doc """
  Returns the list of categories.

  ## Examples

      iex> list_categories()
      [%Category{}, ...]

  """
  def list_categories do
    Repo.all(Category)
  end

  @doc """
  Gets a single category.

  Raises `Ecto.NoResultsError` if the Category does not exist.

  ## Examples

      iex> get_category!(123)
      %Category{}

      iex> get_category!(456)
      ** (Ecto.NoResultsError)

  """
  def get_category!(id), do: Repo.get!(Category, id)

  @doc """
  Creates a category. Requires a superuser scope.

  ## Examples

      iex> create_category(superuser_scope, %{field: value})
      {:ok, %Category{}}

      iex> create_category(non_superuser_scope, %{field: value})
      {:error, :unauthorized}

  """
  def create_category(%Scope{user: %{role: "superuser"}}, attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category. Requires a superuser scope.

  ## Examples

      iex> update_category(superuser_scope, category, %{field: new_value})
      {:ok, %Category{}}

      iex> update_category(non_superuser_scope, category, %{field: value})
      {:error, :unauthorized}

  """
  def update_category(%Scope{user: %{role: "superuser"}}, %Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category. Requires a superuser scope.

  ## Examples

      iex> delete_category(superuser_scope, category)
      {:ok, %Category{}}

      iex> delete_category(non_superuser_scope, category)
      {:error, :unauthorized}

  """
  def delete_category(%Scope{user: %{role: "superuser"}}, %Category{} = category) do
    Repo.delete(category)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking category changes.

  ## Examples

      iex> change_category(category)
      %Ecto.Changeset{data: %Category{}}

  """
  def change_category(%Category{} = category, attrs \\ %{}) do
    Category.changeset(category, attrs)
  end
end
