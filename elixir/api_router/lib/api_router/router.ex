defmodule ApiRouter.Router do
  import Plug.Conn
  use Plug.Router

  @orig "origin"
  @dest "destination"

  plug :match
  plug :dispatch

  get "/route" do
    conn = conn 
      |> Plug.Conn.fetch_query_params()
      |> Plug.Conn.put_resp_header(
        "content-type", "application/json"
      )

    case conn.params do
      %{ @orig => orig, @dest => dest } = params -> 
        params = %{ params | @orig => String.to_integer(orig) }
        params = %{ params | @dest => String.to_integer(dest) }
        send_resp(conn, 200, JSON.encode!(params))
      _ -> 
        send_resp(
          conn, 403, 
          "{ \"error\": \"Bad request\" }" 
        )
    end
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
