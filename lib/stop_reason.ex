defmodule StopReason do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> :finished end, name: __MODULE__)
  end

  def get() do
    Agent.get(__MODULE__, fn x -> x end)
  end

  def set_finished() do
    Agent.update(__MODULE__, fn _x -> :finished end)
  end

  def set_stopped() do
    Agent.update(__MODULE__, fn _x -> :stopped end)
  end

  def set_skipped() do
    Agent.update(__MODULE__, fn _x -> :skipped end)
  end
end
