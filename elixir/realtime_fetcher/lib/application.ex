defmodule TranslinkFetcher.Application do
  use Application

  @impl true
  def start(_type, _args) do
    with {:ok, _} <- Node.start(:"fetcher@127.0.0.1", :longnames) do
      Supervisor.start_link(
        [TranslinkFetcher],
        strategy: :one_for_one,
        name: TranslinkFetcher.Supervisor
      )
    end
  end
end
