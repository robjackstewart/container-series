defmodule App.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting App", version: "1.0.0", environment: System.get_env("MIX_ENV", "dev"))

    OpenTelemetry.register_application_tracer(:app)
    :opentelemetry_cowboy.setup()
    OpentelemetryPhoenix.setup(adapter: :cowboy2)

    children = [
      App.Metrics,
      AppWeb.Telemetry,
      {Phoenix.PubSub, name: App.PubSub},
      AppWeb.Endpoint,
      App.ItemStore
    ]

    opts = [strategy: :one_for_one, name: App.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    AppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end