defmodule Channel do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get(id) do
    Agent.get(__MODULE__, fn map -> Map.get(map, id) end)
  end

  def set(id, channel) do
    Agent.update(__MODULE__, fn map -> Map.put(map, id, channel) end)
  end
end
