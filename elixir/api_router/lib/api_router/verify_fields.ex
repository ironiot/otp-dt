defmodule ApiRouter.VerifyFields do
  defmodule InvlalidFieldsError do
    defexception message: "Fields are invalid."
  end

  def init(options), do: options

  def call(%Plug.Conn{request_path: path} = conn, opts) do
    if ("*" in opts[:paths]) or (path in opts[:paths]) do
      verify_fields(conn.params, opts[:fields])
    end
    conn
  end

  defp verify_fields(params, fields) do
    verified = params 
      |> Map.keys()
      |> contains?(fields)

    if !verified, do: raise(InvlalidFieldsError)
  end

  defp contains?(keys, fields) do
    fields |> Enum.all?(&(&1 in keys))
  end
end
