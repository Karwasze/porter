defmodule Channel do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def get() do
    Agent.get(__MODULE__, fn x -> x end)
  end

  def set(channel) do
    Agent.update(__MODULE__, fn _x -> channel end)
  end
end
