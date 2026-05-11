import Config

config :app, AppWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  url: [host: System.get_env("PHX_HOST") || "localhost", port: 4000],
  cache_static_manifest: nil,
  check_origin: false,
  server: true

config :logger, level: :info
