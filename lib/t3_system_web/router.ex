defmodule T3SystemWeb.Router do
  use T3SystemWeb, :router

  import T3SystemWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {T3SystemWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", T3SystemWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/admin", T3SystemWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :admin,
      on_mount: [{T3SystemWeb.UserAuth, :require_superuser}] do
      # -- Players
      live "/players", PlayerLive.Index, :index
      live "/players/new", PlayerLive.Form, :new
      live "/players/:id", PlayerLive.Show, :show
      live "/players/:id/edit", PlayerLive.Form, :edit

      # -- Leagues
      live "/leagues", LeagueLive.Index, :index
      live "/leagues/new", LeagueLive.Form, :new
      live "/leagues/:id", LeagueLive.Show, :show
      live "/leagues/:id/edit", LeagueLive.Form, :edit

      # -- Events
      live "/events", EventLive.Index, :index
      live "/events/new", EventLive.Form, :new
      live "/events/:id", EventLive.Show, :show
      live "/events/:id/edit", EventLive.Form, :edit

      # -- Categories
      live "/categories", CategoryLive.Index, :index
      live "/categories/new", CategoryLive.Form, :new
      live "/categories/:id", CategoryLive.Show, :show
      live "/categories/:id/edit", CategoryLive.Form, :edit
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", T3SystemWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:t3_system, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: T3SystemWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", T3SystemWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{T3SystemWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", T3SystemWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{T3SystemWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
