defmodule T3System.Tables do
  @moduledoc """
  The Tables context.
  """

  import Ecto.Query, warn: false
  alias T3System.Repo

  alias T3System.Accounts.Scope
  alias T3System.Tables.Table

  @doc """
  Returns the list of tables for the given event, ordered by name.
  """
  def list_tables_for_event(event_id) do
    Table
    |> where([t], t.event_id == ^event_id)
    |> order_by([t], t.name)
    |> Repo.all()
  end

  @doc """
  Gets a single table.

  Raises `Ecto.NoResultsError` if the Table does not exist.
  """
  def get_table!(id), do: Repo.get!(Table, id)

  @doc """
  Creates a table. Requires a superuser scope.
  """
  def create_table(%Scope{user: %{role: "superuser"}}, attrs) do
    %Table{}
    |> Table.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a table. Requires a superuser scope.
  """
  def update_table(%Scope{user: %{role: "superuser"}}, %Table{} = table, attrs) do
    table
    |> Table.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a table. Requires a superuser scope.
  """
  def delete_table(%Scope{user: %{role: "superuser"}}, %Table{} = table) do
    Repo.delete(table)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking table changes.
  """
  def change_table(%Table{} = table, attrs \\ %{}) do
    Table.changeset(table, attrs)
  end
end
