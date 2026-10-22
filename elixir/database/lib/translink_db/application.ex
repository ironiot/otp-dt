defmodule TranslinkDb.Application do
  use Application
  @registry TranslinkDb.Registry

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(
      [
        {Registry, name: @registry, keys: :unique},
        TranslinkDb.Repo,
        TranslinkDb.Query.Data
      ],
      strategy: :one_for_one,
      name: TranslinkDb.Supervisor
    )
  end
end
