alias TranslinkDb.{Data.Type, Data.Static.Worker, Utils.Name}
import ExFuzzywuzzy

defmodule TranslinkDb.Data.Static do
  @moduledoc """
  Anything that needs to read static data goes through this module.

  Is a Supervisor. On start it spawns transient workers to read
  static data from DB into memory.
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

  @spec walk_edges(Type.stop_id()) :: [Type.walk_edge()]
  def walk_edges(stop_id) do
    Worker.get(:walk_edges) |> Map.get(stop_id, [])
  end

  @spec date_services(Date.t()) :: [Type.service_id()]
  def date_services(date) do
    Worker.get(:date_services) |> Map.get(date, [])
  end

  @spec trip_headsign(Type.trip_id()) :: String.t() | nil
  def trip_headsign(trip_id) do
    Worker.get(:trip_headsigns) |> Map.get(trip_id, nil)
  end

  @spec ride_edges([Type.service_id()], Type.stop_id()) :: [Type.ride_edge()]
  def ride_edges(date_services, stop_id) do
    edges_by_service = Worker.get(:ride_edges)

    Enum.flat_map(
      date_services,
      &(edges_by_service |> Map.get(&1, %{}) |> Map.get(stop_id, []))
    )
  end

  @spec stop_id_by_code(Type.stop_code()) :: Type.stop_id() | nil
  def stop_id_by_code(code) do
    # Technically code is not guaranteed unique, but practically it is.
    # It's much better API to query by code (the number on bus stop signs)
    # than by ID (TransLink's internal that no one knows).
    Worker.get(:stop_id_by_code) |> Map.get(code)
  end

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

  @spec stop_name(Type.stop_id()) :: String.t()
  def stop_name(id) do
    Worker.get(:stop_names) |> Map.get(id)
  end
end
