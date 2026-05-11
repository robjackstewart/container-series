defmodule AppWeb.Endpoint do
  use AppWeb, :endpoint

  plug Plug.RequestId
  plug AppWeb.Plugs.StructuredLogger

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason

  plug AppWeb.Router
end
