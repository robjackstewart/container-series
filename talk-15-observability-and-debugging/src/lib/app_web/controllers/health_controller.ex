defmodule AppWeb.HealthController do
  use Phoenix.Controller, formats: [:json]
  require Logger

  def index(conn, _params) do
    Logger.info("Health check requested", endpoint: "/health")
    json(conn, %{status: "healthy", service: "elixir-phoenix-app", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()})
  end

  def ready(conn, _params) do
    json(conn, %{status: "ready"})
  end
end