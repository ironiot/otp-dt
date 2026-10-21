defmodule ApiWeb.Router do
  use ApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ApiWeb do
    pipe_through :api
    get "/", ApiController, :index
    get "/routes", 
      ApiController, :routes
    get "/vehicles/:vehicle_no", 
      ApiController, :vehicles
  end
end
