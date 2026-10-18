# Define a fast CSV parser module using NimbleCSV (RFC 4180 compliant)
NimbleCSV.define(GTFSCSV, separator: ",", escape: "\"")

defmodule Translink.StaticParser do
  @static_gtfs_url "https://gtfs-static.translink.ca/gtfs/google_transit.zip"

  def fetch_and_extract(files_to_extract \\ ["stops.txt", "routes.txt", "trips.txt"]) do
    IO.puts("Downloading TransLink GTFS Static archive...")

    case Req.get(@static_gtfs_url) do
      # Case 1: Req automatically unzipped the archive into a list of {filename, binary} tuples
      {:ok, %Req.Response{status: 200, body: file_list}} when is_list(file_list) ->
        file_list
        |> Enum.map(fn {filename, content} -> {to_string(filename), content} end)
        |> Enum.filter(fn {filename, _content} -> filename in files_to_extract end)
        |> Map.new()

      # Case 2: Fallback if auto-decompression is disabled and body is a raw binary
      {:ok, %Req.Response{status: 200, body: zip_binary}} when is_binary(zip_binary) ->
        charlist_files = Enum.map(files_to_extract, &String.to_charlist/1)
        {:ok, file_list} = :zip.unzip(zip_binary, [:memory, {:file_list, charlist_files}])

        Map.new(file_list, fn {filename, content} ->
          {List.to_string(filename), content}
        end)

      error ->
        raise "Failed to download GTFS data: #{inspect(error)}"
    end
  end

  def parse_stops(csv_binary) do
    csv_binary
    |> parse_csv_with_headers()
    |> Map.new(fn row ->
      {row["stop_id"],
       %{
         stop_code: row["stop_code"],
         name: row["stop_name"],
         lat: parse_float(row["stop_lat"]),
         lon: parse_float(row["stop_lon"])
       }}
    end)
  end


  def parse_routes(csv_binary) do
    csv_binary
    |> parse_csv_with_headers()
    |> Map.new(fn row ->
      {row["route_id"],
       %{
         short_name: String.trim(row["route_short_name"] || ""),
         long_name: String.trim(row["route_long_name"] || "")
       }}
    end)
  end

  @doc """
  Parses trips.txt binary into a map keyed by trip_id.
  """
  def parse_trips(csv_binary) do
    csv_binary
    |> parse_csv_with_headers()
    |> Map.new(fn row ->
      {row["trip_id"],
       %{
         route_id: row["route_id"],
         headsign: row["trip_headsign"],
         direction_id: row["direction_id"]
       }}
    end)
  end


  defp parse_csv_with_headers(csv_binary) do
    # Strip UTF-8 BOM (Byte Order Mark) if present at the start of TransLink's files
    clean_binary = String.replace_prefix(csv_binary, "\uFEFF", "")

    # skip_headers: false lets us capture the first row as our Map keys
    [headers | rows] = GTFSCSV.parse_string(clean_binary, skip_headers: false)

    Stream.map(rows, fn row ->
      Enum.zip(headers, row) |> Map.new()
    end)
  end

  defp parse_float(nil), do: nil
  defp parse_float(""), do: nil

  defp parse_float(str) do
    case Float.parse(str) do
      {num, _} -> num
      :error -> nil
    end
  end
end