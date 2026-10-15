defmodule ApiRouter.FetchQueryParams do
  def init(opts), do: opts

  def call(conn, _opts) do
    conn
      |> Plug.Conn.fetch_query_params()
  end
end
