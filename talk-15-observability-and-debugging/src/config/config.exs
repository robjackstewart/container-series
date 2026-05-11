import Config

config :app, AppWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [json: AppWeb.ErrorJSON], layout: false],
  pubsub_server: App.PubSub,
  server: true

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$message\n"

config :opentelemetry,
  resource: [service: %{name: "elixir-phoenix-app", version: "1.0.0"}],
  processors: [{:otel_batch_processor, %{scheduled_delay_ms: 1_000}}]

config :opentelemetry_exporter,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318"),
  otlp_protocol: :http_protobuf

import_config "#{config_env()}.exs"
