defmodule State do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def init(id) do
    update_map_value(id, :stop_reason, :finished)
    update_map_value(id, :lock, :unlocked)
    update_map_value(id, :queue, [])
    update_map_value(id, :filters, [])
  end

  def get_map_value(id) do
    Agent.get(__MODULE__, fn state ->
      Map.get(state, id)
    end)
  end

  def get_lock(id) do
    Agent.get(__MODULE__, fn state ->
      map = Map.get(state, id)
      map[:lock]
    end)
  end

  def unlock(id) do
    update_map_value(id, :lock, :unlocked)
  end

  def lock(id) do
    update_map_value(id, :lock, :locked)
  end

  def get_stop_reason(id) do
    Agent.get(__MODULE__, fn state ->
      map = Map.get(state, id)
      map[:stop_reason]
    end)
  end

  def set_finished(id) do
    update_map_value(id, :stop_reason, :finished)
  end

  def set_stopped(id) do
    update_map_value(id, :stop_reason, :stopped)
  end

  def set_skipped(id) do
    update_map_value(id, :stop_reason, :skipped)
  end

  def get_song_from_queue(id) do
    Agent.get(__MODULE__, fn state ->
      map = Map.get(state, id)
      map[:queue] |> List.first([])
    end)
  end

  def get_queue(id) do
    Agent.get(__MODULE__, fn state ->
      map = Map.get(state, id)
      map[:queue]
    end)
  end

  def print_queue(id) do
    get_queue(id)
    |> Enum.map(fn {_x, y} -> "#{y}\n" end)
  end

  def add_to_queue(id, url) do
    current = get_queue(id)
    update_map_value(id, :queue, current ++ [url])
  end

  def remove_from_queue(id) do
    case get_queue(id) do
      [_first | rest] -> update_map_value(id, :queue, rest)
      _ -> nil
    end
  end

  def remove_all_from_queue(id) do
    update_map_value(id, :queue, [])
  end

  def get_filters(id) do
    Agent.get(__MODULE__, fn state ->
      map = Map.get(state, id)
      map[:filters]
    end)
  end

  def add_filter(id, url) do
    current = get_filters(id)
    update_map_value(id, :filters, current ++ [url])
  end

  def remove_all_filters(id) do
    update_map_value(id, :filter, [])
  end

  def update_map_value(index, key, new_value) do
    Agent.update(__MODULE__, fn state ->
      map = Map.get(state, index, %{id: index})
      updated_map = Map.put(map, key, new_value)
      Map.put(state, index, updated_map)
    end)
  end
end
