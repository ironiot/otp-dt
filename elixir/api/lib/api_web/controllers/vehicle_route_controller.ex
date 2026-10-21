defmodule ApiWeb.ApiController do
  use ApiWeb, :controller

  def index(conn, _params) do
    render(conn, :help)
  end

  def routes(conn, _params) do
    render(conn, :routes)
  end

  def vehicles(conn, %{"vehicle_no" => num}) do
    render(conn, :vehicles, num: num)
  end

end
