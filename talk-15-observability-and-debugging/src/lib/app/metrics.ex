defmodule App.Metrics do
  use Supervisor

  alias Prometheus.Metric.Counter
  alias Prometheus.Metric.Histogram

  @request_counter :app_http_requests_total
  @error_counter :app_http_errors_total
  @duration_histogram :app_http_request_duration_milliseconds

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    declare_metrics()
    Supervisor.init([], strategy: :one_for_one)
  end

  def observe_request(method, route, status, duration_ms) do
    status_label = Integer.to_string(status)

    Counter.inc(name: @request_counter, labels: [method, route, status_label])
    Histogram.observe(name: @duration_histogram, labels: [method, route], value: duration_ms)

    if status >= 400 do
      Counter.inc(name: @error_counter, labels: [method, route, status_label])
    end
  end

  def export, do: Prometheus.Format.Text.format()

  defp declare_metrics do
    safe_declare(fn ->
      Counter.declare(
        name: @request_counter,
        help: "Total HTTP requests served by the Phoenix API.",
        labels: [:method, :route, :status]
      )
    end)

    safe_declare(fn ->
      Counter.declare(
        name: @error_counter,
        help: "Total HTTP error responses served by the Phoenix API.",
        labels: [:method, :route, :status]
      )
    end)

    safe_declare(fn ->
      Histogram.declare(
        name: @duration_histogram,
        help: "HTTP request duration in milliseconds.",
        labels: [:method, :route],
        buckets: [5, 10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000]
      )
    end)
  end

  defp safe_declare(fun) do
    fun.()
  rescue
    _ -> :ok
  end
end