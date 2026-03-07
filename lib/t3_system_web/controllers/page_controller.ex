defmodule T3SystemWeb.PageController do
  use T3SystemWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
