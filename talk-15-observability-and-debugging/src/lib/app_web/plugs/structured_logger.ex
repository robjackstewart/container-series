defmodule AppWeb.Plugs.StructuredLogger do
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time()

    register_before_send(conn, fn conn ->
      duration_ms =
        System.monotonic_time()
        |> Kernel.-(start_time)
        |> System.convert_time_unit(:native, :microsecond)
        |> Kernel./(1_000)

      request_id = List.first(get_resp_header(conn, "x-request-id"))

      payload = %{
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        level: "info",
        request_id: request_id,
        method: conn.method,
        path: conn.request_path,
        status: conn.status,
        duration_ms: Float.round(duration_ms, 2),
        remote_ip: conn.remote_ip |> :inet.ntoa() |> to_string()
      }

      App.Metrics.observe_request(conn.method, conn.request_path, conn.status || 200, duration_ms)
      Logger.info(Jason.encode!(payload))
      conn
    end)
  end
end
