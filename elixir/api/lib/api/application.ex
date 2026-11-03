defmodule Api.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @table    Api.Table
  @registry TranslinkDb.Registry

  @impl true
  def start(_type, _args) do
    children = [
      ApiWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Api.PubSub},
      {Registry, name: @registry, keys: :unique},
      # Start a worker by calling: Api.Worker.start_link(arg)
      # {Api.Worker, arg},
      {Api.Worker, nil},

      # Start to serve requests, typically the last entry
      ApiWeb.Endpoint
    ]

    System.cmd("epmd", ["-daemon"])
    Node.start(:api, name_domain: :shortnames)
    Node.connect(System.get_env("DB_HOST") |> String.to_atom)
    :ets.new(@table, [:set, :public, :named_table])
    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Api.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
