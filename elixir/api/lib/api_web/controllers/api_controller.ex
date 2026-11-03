defmodule ApiWeb.ApiController do
  use ApiWeb, :controller

  def index(conn, _params) do
    render(conn, :help)
  end

  def route(conn, 
    %{ 
      "orig" => orig,
      "dest" => dest,
      "time" => time
    }
  ) do
    render(
      conn, :routes,
      orig: orig,
      dest: dest,
      time: time
    )
  end

  def route(conn, 
    %{ 
      "orig" => orig,
      "dest" => dest
    }
  ) do
    render(
      conn, :routes,
      orig: orig,
      dest: dest,
      time: nil
    )
  end

  def vehicles(conn, %{"vehicle_no" => num}) do
    render(conn, :vehicles, num: num)
  end

end
