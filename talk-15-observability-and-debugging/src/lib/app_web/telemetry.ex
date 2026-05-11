defmodule AppWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    children = [{Telemetry.Poller, measurements: periodic_measurements(), period: 10_000}]
    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.stop.duration", tags: [:route], unit: {:native, :millisecond}),
      last_value("app.vm.memory.total", event_name: [:app, :vm], measurement: :memory_total, unit: {:byte, :megabyte}),
      last_value("app.vm.process.count", event_name: [:app, :vm], measurement: :process_count),
      last_value("app.vm.total_run_queue", event_name: [:app, :vm], measurement: :total_run_queue)
    ]
  end

  def dispatch_vm_metrics do
    :telemetry.execute(
      [:app, :vm],
      %{
        memory_total: :erlang.memory(:total),
        process_count: :erlang.system_info(:process_count),
        total_run_queue: :erlang.statistics(:total_run_queue_lengths)
      },
      %{}
    )
  end

  defp periodic_measurements do
    [{__MODULE__, :dispatch_vm_metrics, []}]
  end
end
