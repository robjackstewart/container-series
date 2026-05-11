defmodule AppWeb.Router do
  use AppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AppWeb do
    pipe_through :api

    get "/health", HealthController, :index
    get "/ready", HealthController, :ready
    get "/metrics", MetricsController, :index
    resources "/items", ItemController, only: [:index, :show, :create, :delete]
  end
end
