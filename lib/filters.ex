defmodule Filters do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def init(id) do
    Agent.update(__MODULE__, fn map -> Map.put_new(map, id, []) end)
  end

  def get_all(id) do
    Agent.get(__MODULE__, fn map -> Map.get(map, id) end)
  end

  def add(id, url) do
    current = Agent.get(__MODULE__, fn map -> Map.get(map, id) end)
    Agent.update(__MODULE__, fn map -> Kernel.put_in(map[id], current ++ [url]) end)
  end

  def remove_all(id) do
    Agent.update(__MODULE__, fn map -> Kernel.put_in(map[id], []) end)
  end
end
