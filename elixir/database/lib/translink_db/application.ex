defmodule TranslinkDb.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TranslinkDb.Repo
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: TranslinkDb.Supervisor)
  end
end
