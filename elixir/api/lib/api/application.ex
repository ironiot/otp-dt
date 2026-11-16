defmodule Api.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @table Api.Table
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
    :ets.new(@table, [:set, :public, :named_table])

    with {:ok, _} <- Node.start(:"api@127.0.0.1", :longnames),
         true <- Node.connect(:"db@127.0.0.1") do
      Supervisor.start_link(
        children,
        strategy: :one_for_one,
        name: Api.Supervisor
      )
    else
      {:error, node_start_error} -> {:error, node_start_error}
      false -> {:error, "Failed to connect to TranslinkDb"}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
