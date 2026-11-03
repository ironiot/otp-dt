defmodule ApiWeb.ApiJSON do
  def help(_assigns) do
    %{ "commands" => [
        "route/:orig/:dest", 
        "route/:orig/:dest/:time", 
        "vehicles/:vehicle_no",
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

  def vehicles(assigns) do
    %{vehicle_no: assigns.num}
  end
end
