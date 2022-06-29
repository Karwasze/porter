defmodule StopReason do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def init(id) do
    Agent.update(__MODULE__, fn map -> Map.put_new(map, id, :finished) end)
  end

  def get(id) do
    Agent.get(__MODULE__, fn map -> Map.get(map, id) end)
  end

  def set_finished(id) do
    Agent.update(__MODULE__, fn map -> Map.put(map, id, :finished) end)
  end

  def set_stopped(id) do
    Agent.update(__MODULE__, fn map -> Map.put(map, id, :stopped) end)
  end

  def set_skipped(id) do
    Agent.update(__MODULE__, fn map -> Map.put(map, id, :skipped) end)
  end
end
