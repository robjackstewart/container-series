defmodule AppWeb.MetricsController do
  use AppWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, App.Metrics.export())
  end
end
