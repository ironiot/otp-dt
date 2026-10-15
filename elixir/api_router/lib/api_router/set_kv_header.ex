defmodule ApiRouter.SetKVHeader do
  def init(opts), do: opts

  def call(%Plug.Conn{request_path: path} = conn, opts) do
    if ("*" in opts[:paths]) or (path in opts[:paths]) do
      conn 
        |> Plug.Conn.put_resp_header(opts[:key], opts[:val]) 
    else
      conn
    end
  end
end
