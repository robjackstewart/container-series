import Config

config :app, AppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  debug_errors: true,
  code_reloader: false,
  check_origin: false,
  secret_key_base: "dev-secret-key-base-for-container-series",
  watchers: []

config :logger, level: :debug
