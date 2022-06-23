defmodule Queue do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def get do
    Agent.get(__MODULE__, fn list -> List.first(list, []) end)
  end

  def get_all do
    Agent.get(__MODULE__, fn list -> list end)
  end

  def add(url) do
    Agent.update(__MODULE__, fn list -> list ++ [url] end)
  end

  def remove() do
    Agent.update(__MODULE__, fn list -> List.delete_at(list, 0) end)
  end
end
