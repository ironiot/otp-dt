defmodule ApiWeb.ApiJSON do
  def help(_assigns) do
    %{ "commands" => ["routes/", "vehicles/:vehicle_no"] }
  end

  def routes(_assigns) do
    %{ "routes" => [] }
  end

  def vehicles(assigns) do
    %{vehicle_no: assigns.num}
  end
end
