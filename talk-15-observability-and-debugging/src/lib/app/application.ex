defmodule App.Application do
  use Application

  @impl true
  def start(_type, _args) do
    OpenTelemetry.register_application_tracer(:app)

    children = [
      App.Metrics,
      AppWeb.Telemetry,
      App.ItemStore,
      {Phoenix.PubSub, name: App.PubSub},
      AppWeb.Endpoint
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
