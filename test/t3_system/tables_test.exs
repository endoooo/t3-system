defmodule T3System.TablesTest do
  use T3System.DataCase

  alias T3System.Accounts.Scope
  alias T3System.Tables
  alias T3System.Tables.Table

  import T3System.Factory

  describe "tables" do
    test "list_tables_for_event/1 returns tables ordered by name" do
      event = insert(:event)
      t2 = insert(:table, event: event, name: "Table B")
      t1 = insert(:table, event: event, name: "Table A")
      _other = insert(:table)

      results = Tables.list_tables_for_event(event.id)
      assert [first, second] = results
      assert first.id == t1.id
      assert second.id == t2.id
    end

    test "get_table!/1 returns the table" do
      table = insert(:table)
      assert Tables.get_table!(table.id).id == table.id
    end

    test "create_table/2 with valid attrs creates a table" do
      superuser = insert(:superuser)
      scope = %Scope{user: superuser}
      event = insert(:event)

      assert {:ok, %Table{} = table} =
               Tables.create_table(scope, %{name: "Table 1", event_id: event.id})

      assert table.name == "Table 1"
      assert table.event_id == event.id
    end

    test "create_table/2 requires name" do
      superuser = insert(:superuser)
      scope = %Scope{user: superuser}
      event = insert(:event)

      assert {:error, changeset} = Tables.create_table(scope, %{event_id: event.id})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_table/2 requires event_id" do
      superuser = insert(:superuser)
      scope = %Scope{user: superuser}

      assert {:error, changeset} = Tables.create_table(scope, %{name: "Table 1"})
      assert %{event_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_table/3 updates the table" do
      superuser = insert(:superuser)
      scope = %Scope{user: superuser}
      table = insert(:table)

      assert {:ok, updated} = Tables.update_table(scope, table, %{name: "Updated"})
      assert updated.name == "Updated"
    end

    test "delete_table/2 deletes the table" do
      superuser = insert(:superuser)
      scope = %Scope{user: superuser}
      table = insert(:table)

      assert {:ok, _} = Tables.delete_table(scope, table)
      assert_raise Ecto.NoResultsError, fn -> Tables.get_table!(table.id) end
    end

    test "change_table/2 returns a changeset" do
      table = insert(:table)
      assert %Ecto.Changeset{} = Tables.change_table(table)
    end
  end
end
