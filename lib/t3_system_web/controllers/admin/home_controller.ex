defmodule T3SystemWeb.Admin.HomeController do
  use T3SystemWeb, :controller

  alias T3System.Accounts.Scope

  # Where `/admin` lands. Change this to point the admin entry point elsewhere.
  @admin_home_path "/admin/players"

  def index(%{assigns: %{current_scope: %Scope{user: %{role: "superuser"}}}} = conn, _params) do
    redirect(conn, to: @admin_home_path)
  end

  def index(_conn, _params), do: raise(T3SystemWeb.Errors.NotFound)
end
