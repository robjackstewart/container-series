import Config

port = String.to_integer(System.get_env("PORT") || "4000")

config :app, AppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: port],
  server: true

if System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") do
  config :opentelemetry_exporter,
    otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT")
end