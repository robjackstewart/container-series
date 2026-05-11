defmodule AppWeb.HealthController do
  use AppWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      status: "healthy",
      service: "elixir-phoenix",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def ready(conn, _params) do
    json(conn, %{status: "ready"})
  end
end
