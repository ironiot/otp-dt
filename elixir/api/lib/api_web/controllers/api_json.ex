defmodule ApiWeb.ApiJSON do
  def help(_assigns) do
    %{ "commands" => [
        "route/:orig/:dest", 
        "route/:orig/:dest/:time",
        "route/:orig/:dest/arrive/:time",
        "vehicles/:vehicle_no",
        "realtime/upcoming_rides/:stop_id/",
        "realtime/upcoming_rides/:stop_id/:time",
      ] 
    }
  end

  def route(assigns) when assigns.time == nil do
    Api.Worker.route(assigns.orig, assigns.dest)
  end

  def route(assigns) do
    case DateTime.from_iso8601(assigns.time <> "+00:00") do
      { :ok, dt, _ } ->
        Api.Worker.route(assigns.orig, assigns.dest, {:departure, dt})
      {:error, msg} -> %{ 
        error: "Error parsing #{assigns.time}. Try again.",
        reason: msg
      }
    end
  end

  # Time is Pacific wall-clock, e.g. 2026-11-23T09:00:00.
  # Sent without a zone; the DB node converts it to Pacific time.
  def route_arrive(assigns) do
    case NaiveDateTime.from_iso8601(assigns.time) do
      {:ok, naive} ->
        Api.Worker.route(assigns.orig, assigns.dest, {:arrival, naive})
      {:error, msg} -> %{
        error: "Error parsing #{assigns.time}. Try again.",
        reason: msg
      }
    end
  end

  def vehicles(assigns) do
    %{vehicle_no: assigns.num}
  end

  def upcoming_rides(assigns) when assigns.time == nil do
    Api.Worker.upcoming_rides(assigns.stop_id)
  end

  def upcoming_rides(assigns) do
    case DateTime.from_iso8601(assigns.time <> "+00:00") do
      { :ok, dt, _ } ->
        Api.Worker.upcoming_rides(assigns.stop_id, dt)
      {:error, msg} -> %{ 
        error: "Error parsing #{assigns.time}. Try again.",
        reason: msg
      }
    end
  end
end
