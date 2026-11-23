defmodule ApiWeb.Router do
  use ApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ApiWeb do
    pipe_through :api
    
    get "/", ApiController, :index

    get "/route/:orig/:dest", 
      ApiController, :route

    get "/route/:orig/:dest/:time",
      ApiController, :route

    get "/route/:orig/:dest/arrive/:time",
      ApiController, :route_arrive

    get "/vehicles/:vehicle_no", 
      ApiController, :vehicles

    get "/realtime/upcoming_rides/:stop_id/:time",
      ApiController, :upcoming_rides

    get "/realtime/upcoming_rides/:stop_id",
      ApiController, :upcoming_rides
  end
end
