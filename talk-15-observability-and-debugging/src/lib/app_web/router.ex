defmodule AppWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AppWeb do
    pipe_through :api

    get "/health", HealthController, :index
    get "/ready", HealthController, :ready
    get "/metrics", MetricsController, :index

    get "/items", ItemController, :index
    post "/items", ItemController, :create
    get "/items/:id", ItemController, :show
    delete "/items/:id", ItemController, :delete
  end
end