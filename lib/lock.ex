defmodule Lock do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> :unlocked end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, fn x -> x end)
  end

  def lock() do
    Agent.update(__MODULE__, fn _x -> :locked end)
  end

  def unlock() do
    Agent.update(__MODULE__, fn _x -> :unlocked end)
  end
end
