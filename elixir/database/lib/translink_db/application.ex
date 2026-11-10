defmodule TranslinkDb.Application do
  use Application
  @registry TranslinkDb.Registry

  @impl true
  def start(_type, _args) do
    children =
      [TranslinkDb.Repo] ++
        if Application.get_env(:translink_db, :start_services, true) do
          [
            {Registry, name: @registry, keys: :unique},
            TranslinkDb.Data.Static,
            TranslinkDb.Data.Realtime,
            TranslinkDb.Query.Server
          ]
        else
          []
        end

    with {:ok, _} <- Node.start(:"db@127.0.0.1", :longnames),
         true <- Node.connect(:"fetcher@127.0.0.1") do
      Supervisor.start_link(
        children,
        strategy: :one_for_one,
        name: TranslinkDb.Supervisor
      )
    else
      {:error, node_start_error} -> {:error, node_start_error}
      false -> {:error, "Failed to connect to TranslinkFetcher"}
    end
  end
end
