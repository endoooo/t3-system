defmodule T3System.Categories do
  @moduledoc """
  The Categories context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Categories.Category
  alias T3System.Registrations.Registration

  @doc """
  Returns the list of categories.

  ## Examples

      iex> list_categories()
      [%Category{}, ...]

  """
  def list_categories do
    Category
    |> order_by(:name)
    |> Repo.all()
  end

  def list_categories_by_ids([]), do: []

  def list_categories_by_ids(ids) do
    Repo.all(from c in Category, where: c.id in ^ids)
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
    |> validate_format_unlocked(category)
    |> Repo.update()
  end

  @doc """
  Returns true when the category's format can no longer change, because a
  registration exists for it in any event.
  """
  @spec format_locked?(Category.t()) :: boolean()
  def format_locked?(%Category{id: nil}), do: false

  def format_locked?(%Category{id: id}) do
    Repo.exists?(from r in Registration, where: r.category_id == ^id)
  end

  defp validate_format_unlocked(changeset, category) do
    if Ecto.Changeset.get_change(changeset, :format) && format_locked?(category) do
      Ecto.Changeset.add_error(
        changeset,
        :format,
        "can't be changed once the category has registrations"
      )
    else
      changeset
    end
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
