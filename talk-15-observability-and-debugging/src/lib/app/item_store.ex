defmodule App.ItemStore do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn ->
      [
        %{id: 1, name: "Phoenix Item", description: "Built with Elixir Phoenix"},
        %{id: 2, name: "OTel Widget", description: "Fully instrumented with OpenTelemetry"}
      ]
    end, name: __MODULE__)
  end

  def all, do: Agent.get(__MODULE__, & &1)
  def get(id), do: Agent.get(__MODULE__, fn items -> Enum.find(items, &(&1.id == id)) end)
  def add(item), do: Agent.update(__MODULE__, fn items -> items ++ [item] end)
  def delete(id), do: Agent.update(__MODULE__, fn items -> Enum.reject(items, &(&1.id == id)) end)

  def next_id do
    Agent.get(__MODULE__, fn
      [] -> 1
      items -> Enum.max_by(items, & &1.id).id + 1
    end)
  end
end