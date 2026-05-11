import Config

config :app, AppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  secret_key_base: "test-secret-key-base-for-container-series"

config :logger, level: :warning
