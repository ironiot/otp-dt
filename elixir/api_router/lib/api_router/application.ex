defmodule ApiRouter.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      { Bandit, 
        scheme: :http, 
        plug: ApiRouter.Router, 
        port: 8080,
      },
    ]

    Logger.info("Starting application.")
    opts = [strategy: :one_for_one, name: ApiRouter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
