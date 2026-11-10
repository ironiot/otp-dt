alias TranslinkDb.{Data.Type, Data.Static.Worker, Utils.Name}
import ExFuzzywuzzy

defmodule TranslinkDb.Data.Static do
  @moduledoc """
  Anything that needs static data should use this module, not read DB directly.

  Is a Supervisor. On start it spawns transient workers to read
  all necessary data from DB into memory.
  """

  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    [
      :ride_edges,
      :walk_edges,
      :date_services,
      :trip_headsigns,
      :stop_id_by_code,
      :stop_ids_by_name,
      :stop_names
    ]
    |> Enum.map(&Supervisor.child_spec({Worker, &1}, id: &1, restart: :transient))
    |> Supervisor.init(strategy: :one_for_one)
  end

  @doc """
  Given a stop, get a list of stops walkable from that one.
  """
  @spec walk_edges(Type.stop_id()) :: [Type.walk_edge()]
  def walk_edges(stop_id) do
    Worker.get(:walk_edges) |> Map.get(stop_id, [])
  end

  @doc """
  Given a date, get a list of active service IDs on that date.
  """
  @spec date_services(Date.t()) :: [Type.service_id()]
  def date_services(date) do
    Worker.get(:date_services) |> Map.get(date, [])
  end

  @doc "Get a trip headsign from its ID."
  @spec trip_headsign(Type.trip_id()) :: String.t() | nil
  def trip_headsign(trip_id) do
    Worker.get(:trip_headsigns) |> Map.get(trip_id, nil)
  end

  @doc """
  Given a stop, get a list of stops reachable via a direct ride from that one.
  (Direct ride means not going through any other stop.)

  Ride edges depends on date, the 2nd argument is the
  list of active service IDs on the date of interest.
  Use `date_services/1` to get that list, like this:

  ```
  ride_edges(stop_id, date_services(date))
  ```

  This 2-step process (instead of `ride_edges(stop_id, date)`)
  is necessary for performance.
  """
  @spec ride_edges(Type.stop_id(), [Type.service_id()]) :: [Type.ride_edge()]
  def ride_edges(stop_id, date_services) do
    edges_by_service = Worker.get(:ride_edges)

    Enum.flat_map(
      date_services,
      &(edges_by_service |> Map.get(&1, %{}) |> Map.get(stop_id, []))
    )
  end

  @doc """
  Get a stop ID by its code.

  Stop code is the number printed on bus stop signs.
  Stop ID is TransLink's internal that no one knows, but is used by the database.
  """
  @spec stop_id_by_code(Type.stop_code()) :: Type.stop_id() | nil
  def stop_id_by_code(code) do
    Worker.get(:stop_id_by_code) |> Map.get(code)
  end

  @doc """
  Get a list of stop IDs by name, using fuzzy string matching.

  E.g. "new west" -> the stop IDs of

  - New Westminster Station @ Bay 1
  - New Westminster Station @ Bay 9
  - New Westminster Station @ Bay 3
  - New Westminster Station @ Bay 2
  - New Westminster Station @ Bay 4
  - New Westminster Station @ Bay 5
  - New Westminster Station @ Bay 7
  - New Westminster Station @ Bay 8
  - New Westminster Station @ Unloading Only
  - New Westminster Station @ Platform 2
  - New Westminster Station @ Platform 1
  - Westbound 8th Ave @ New Westminster Secondary

  The last one is probably not what you intended.
  It's not magic. If you use imprecise names, expect imprecise results.
  """
  @spec stop_ids_by_name(String.t()) :: [Type.stop_id()]
  def stop_ids_by_name(searched_name) do
    searched_name = Name.normalize(searched_name)

    Worker.get(:stop_ids_by_name)
    |> Enum.map(fn {stop_name, stop_ids} ->
      Task.async(fn ->
        %{
          match: partial_ratio(searched_name, stop_name),
          stop_ids: stop_ids
        }
      end)
    end)
    |> Enum.map(&Task.await/1)
    |> Enum.group_by(& &1.match, & &1.stop_ids)
    |> Enum.sort_by(fn {match, _ids_groups} -> match end, :desc)
    |> then(
      &case &1 do
        [{_match, ids_groups} | _] -> Enum.concat(ids_groups)
        [] -> []
      end
    )
  end

  @doc "Get a stop name from its ID."
  @spec stop_name(Type.stop_id()) :: String.t()
  def stop_name(id) do
    Worker.get(:stop_names) |> Map.get(id)
  end
end
