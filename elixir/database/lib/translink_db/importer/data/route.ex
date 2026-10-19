defmodule TranslinkDb.Importer.Route do
  alias TranslinkDb.Importer.{Batch, CSV, Parser}
  alias TranslinkDb.Schemas.Route

  @spec import_data(map()) :: :ok
  def import_data(feed) do
    IO.puts("\nImporting routes")

    routes =
      feed
      |> Map.fetch!("routes.txt")
      |> CSV.stream("routes.txt")
      |> Enum.reduce([], fn row, routes ->
        with {:ok, id} <- Parser.integer(row, "route_id"),
             {:ok, attrs} <- route_attrs(row, id) do
          [attrs | routes]
        else
          {:error, message} ->
            IO.puts("Discarding row: #{message}")
            routes
        end
      end)
      |> Enum.reverse()

    Batch.insert_in_batches(Route, routes)
  end

  defp route_attrs(row, id) do
    with {:ok, short_name} <- Parser.string(row, "route_short_name"),
         {:ok, name} <- route_name(row, short_name) do
      {:ok, %{id: id, name: name}}
    end
  end

  defp route_name(row, "") do
    Parser.string(row, "route_long_name")
  end

  defp route_name(_row, short_name), do: {:ok, short_name}
end
