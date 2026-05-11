defmodule App.ItemStore do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> seed_items() end, name: __MODULE__)
  end

  def get_all do
    Agent.get(__MODULE__, & &1)
  end

  def get(id) do
    Agent.get(__MODULE__, fn items -> Enum.find(items, &(&1.id == id)) end)
  end

  def add(item) do
    Agent.update(__MODULE__, fn items -> items ++ [item] end)
    item
  end

  def delete(id) do
    Agent.get_and_update(__MODULE__, fn items ->
      {removed, remaining} = Enum.split_with(items, &(&1.id == id))
      {removed != [], remaining}
    end)
  end

  def next_id do
    Agent.get(__MODULE__, fn
      [] -> 1
      items -> Enum.max_by(items, & &1.id).id + 1
    end)
  end

  defp seed_items do
    [
      %{id: 1, name: "Phoenix Item", description: "A lively item"},
      %{id: 2, name: "Elixir Brew", description: "A potent brew"}
    ]
  end
end
