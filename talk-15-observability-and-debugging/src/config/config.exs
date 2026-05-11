import Config

config :app, AppWeb.Endpoint,
  url: [host: "localhost"],
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: "a-very-long-secret-key-base-for-development-only-change-in-production",
  render_errors: [formats: [json: AppWeb.ErrorJSON], layout: false],
  pubsub_server: App.PubSub

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$message\n",
  metadata: [:request_id, :item_id, :item_name]

config :opentelemetry,
  resource: [service: [name: "elixir-phoenix-app", version: "1.0.0"]],
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://otel-collector:4318"

import_config "#{config_env()}.exs"