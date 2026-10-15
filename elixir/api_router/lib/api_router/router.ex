defmodule ApiRouter.Router do
  import Plug.Conn
  use Plug.ErrorHandler
  use Plug.Router

  @orig "origin"
  @dest "destination"

  plug ApiRouter.FetchQueryParams
  plug ApiRouter.VerifyFields, fields: [@orig, @dest],
    paths: ["/route"]
  plug ApiRouter.SetKVHeader,
    key: "content-type",
    val: "application/json",
    paths: ["*"]
  plug :match
  plug :dispatch

  get "/route" do
    send_resp(
      conn, 200, JSON.encode_to_iodata!(conn.query_params)
    )
  end

  get "/vehicle/:num" do
    send_resp(
      conn, 200, JSON.encode_to_iodata!(
        %{ "request_type" => "vehicle", 
           "num" => num,
           "desc" => "this would get latest vehicle details"
        }
      )
    )
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  def handle_errors(conn, %{reason: reason}) do
    %{ message: msg } = Map.from_struct(reason)
    send_resp(
      conn, conn.status, 
      JSON.encode_to_iodata!(%{ error: msg })
    );
  end
end
