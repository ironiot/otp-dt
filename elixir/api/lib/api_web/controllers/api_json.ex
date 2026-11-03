defmodule ApiWeb.ApiJSON do
  def help(_assigns) do
    %{ "commands" => ["routes/", "vehicles/:vehicle_no"] }
  end

  def route(assigns) do
    if assigns.time != nil do
      Api.Worker.route(assigns.orig, assigns.dest, assigns.time)
    else
      Api.Worker.route(assigns.orig, assigns.dest)
    end
  end

  def vehicles(assigns) do
    %{vehicle_no: assigns.num}
  end
end
