defmodule T3System.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      T3SystemWeb.Telemetry,
      T3System.Repo,
      {DNSCluster, query: Application.get_env(:t3_system, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: T3System.PubSub},
      # Start a worker by calling: T3System.Worker.start_link(arg)
      # {T3System.Worker, arg},
      # Start to serve requests, typically the last entry
      T3SystemWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: T3System.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    T3SystemWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
