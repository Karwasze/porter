defmodule Player do
  use GenServer
  alias Alchemy.Voice
  # Callbacks

  @impl true
  def init(stack) do
    {:ok, stack}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, List.first(state, []), state}
  end

  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:remove, state) do
    {:noreply, List.delete_at(state, 0)}
  end

  @impl true
  def handle_cast({:add, url}, state) do
    {:noreply, state ++ [url]}
  end

  def handle_cast({:play, id}, state) do
    song = List.first(state, [])
    IO.puts("PLAYING #{song}")

    case song do
      [] ->
        nil

      _ ->
        Voice.play_url(id, song)
        Voice.wait_for_end(id)
        IO.puts("audio has stopped in #{id}")
    end

    {:noreply, state}
  end

  def handle_call({:stop, id}, _from, state) do
    Voice.stop_audio(id)
    IO.puts("STOPPED")
    {:reply, :ok, state}
  end
end
