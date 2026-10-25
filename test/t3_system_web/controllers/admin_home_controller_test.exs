defmodule T3SystemWeb.Admin.HomeControllerTest do
  use T3SystemWeb.ConnCase, async: true

  import T3System.Factory

  test "redirects an admin to the admin home page", %{conn: conn} do
    conn = conn |> log_in_user(insert(:superuser)) |> get(~p"/admin")

    assert redirected_to(conn) == ~p"/admin/players"
  end

  test "404s for a non-admin user", %{conn: conn} do
    conn = log_in_user(conn, insert(:user))

    assert_raise T3SystemWeb.Errors.NotFound, fn -> get(conn, ~p"/admin") end
  end

  test "redirects an anonymous visitor to log in", %{conn: conn} do
    conn = get(conn, ~p"/admin")

    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
