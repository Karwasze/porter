defmodule Queue do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def init(id) do
    Agent.update(__MODULE__, fn map -> Map.put_new(map, id, []) end)
  end

  def get(id) do
    Agent.get(__MODULE__, fn map -> Map.get(map, id) |> List.first([]) end)
  end

  def print_queue(id) do
    current = Agent.get(__MODULE__, fn map -> Map.get(map, id) end)

    case current do
      nil ->
        Agent.get(__MODULE__, fn map -> [] end)

      _ ->
        Agent.get(__MODULE__, fn map ->
          Map.get(map, id) |> Enum.map(fn {_x, y} -> "#{y}\n" end)
        end)
    end
  end

  def print_queue(id) do
  end

  def add(id, url) do
    current = Agent.get(__MODULE__, fn map -> Map.get(map, id) end)
    Agent.update(__MODULE__, fn map -> Kernel.put_in(map[id], current ++ [url]) end)
  end

  def remove(id) do
    current = Agent.get(__MODULE__, fn map -> Map.get(map, id) end)
    Agent.update(__MODULE__, fn map -> Kernel.put_in(map[id], List.delete_at(current, 0)) end)
  end

  def remove_all(id) do
    Agent.update(__MODULE__, fn map -> Kernel.put_in(map[id], []) end)
  end
end
