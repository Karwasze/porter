defmodule Lock do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def init(id) do
    Agent.update(__MODULE__, fn map -> Map.put_new(map, id, :unlocked) end)
  end

  def get(id) do
    Agent.get(__MODULE__, fn map -> Map.get(map, id) end)
  end

  def lock(id) do
    Agent.update(__MODULE__, fn map -> Map.put(map, id, :locked) end)
  end

  def unlock(id) do
    Agent.update(__MODULE__, fn map -> Map.put(map, id, :unlocked) end)
  end
end
