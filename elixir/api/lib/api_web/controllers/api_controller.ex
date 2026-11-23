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
      conn, :route,
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
      conn, :route,
      orig: orig,
      dest: dest,
      time: nil
    )
  end

  def route_arrive(conn,
    %{
      "orig" => orig,
      "dest" => dest,
      "time" => time
    }
  ) do
    render(
      conn, :route_arrive,
      orig: orig,
      dest: dest,
      time: time
    )
  end

  def vehicles(conn, %{"vehicle_no" => num}) do
    render(conn, :vehicles, num: num)
  end

  def upcoming_rides(conn, 
    %{"stop_id" => stop_id, "time" => t}
  ) do
    render(conn, :upcoming_rides, stop_id: stop_id, time: t)
  end

  def upcoming_rides(conn, %{"stop_id" => stop_id}) do
    render(conn, :upcoming_rides, stop_id: stop_id, time: nil)
  end
end
