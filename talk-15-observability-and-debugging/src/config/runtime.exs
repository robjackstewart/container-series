import Config

if config_env() == :prod do
  port = String.to_integer(System.get_env("PORT") || "4000")
  host = System.get_env("PHX_HOST") || "localhost"

  config :app, AppWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: port],
    url: [host: host, port: port],
    secret_key_base:
      System.get_env("SECRET_KEY_BASE") ||
        "Z0FBQUFBQm10Q29udGFpbmVyU2VyaWVzT2JzZXJ2YWJpbGl0eURlbW9TZWNyZXRLZXlCYXNl"
end
