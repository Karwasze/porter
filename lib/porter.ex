defmodule Porter do
  use Application
  alias Alchemy.Client

  defmodule Commands do
    use Alchemy.Cogs
    alias Alchemy.Voice
    alias Alchemy.Client
    Cogs.set_parser(:play, &List.wrap/1)

    Cogs.def play("") do
      {:ok, id} = Cogs.guild_id()
      _handle_lock(id)
    end

    Cogs.def play(query) do
      {:ok, id} = Cogs.guild_id()
      {:ok, url} = Utils.search(query)
      Queue.add(url)
      Cogs.say("#{url} added")
      _handle_lock(id)
    end

    Cogs.def stop do
      {:ok, id} = Cogs.guild_id()

      StopReason.set_stopped()

      Voice.stop_audio(id)
      song_name = Queue.get()
      Cogs.say("#{song_name} stopped")
    end

    Cogs.def skip do
      {:ok, id} = Cogs.guild_id()

      StopReason.set_skipped()

      Voice.stop_audio(id)
      song_name = Queue.get()
      Cogs.say("#{song_name} skipped")
    end

    Cogs.def queue do
      queue = Queue.get_all()

      msg =
        case queue do
          [] -> "Queue is empty, add a song using !play <query> command!"
          _ -> "Queue: #{queue}"
        end

      Cogs.say(msg)
    end

    Cogs.def add(query) do
      {:ok, url} = Utils.search(query)
      Queue.add(url)
      Cogs.say("Added #{url} to queue")
    end

    Cogs.def remove do
      url = Queue.get()
      Queue.remove()
      Cogs.say("Removed #{url} to queue")
    end

    Cogs.def leave do
      {:ok, id} = Cogs.guild_id()

      case Voice.leave(id) do
        :ok -> nil
        {:error, error} -> Cogs.say("Oops #{error}")
      end
    end

    defp _handle_lock(id) do
      case Lock.get() do
        :locked ->
          nil

        :unlocked ->
          StopReason.set_finished()
          Lock.lock()
          _play(id)
      end
    end

    defp _play(id) do
      {:ok, channel} = Client.get_channels(id)
      default_voice_channel = Enum.find(channel, &match?(%{name: "General"}, &1))
      Voice.join(id, default_voice_channel.id)

      case Queue.get() do
        [] ->
          nil

        _ ->
          Voice.play_url(id, Queue.get())
          Voice.wait_for_end(id)

          case StopReason.get() do
            :stopped ->
              Lock.unlock()

            _ ->
              Queue.remove()
              Lock.unlock()
              _play(id)
          end
      end
    end
  end

  def start(_type, _args) do
    token = Application.fetch_env!(:porter, :discord_token)
    run = Client.start(token)

    children = [
      Queue,
      Lock,
      StopReason
    ]

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_all)
    use Commands
    run
  end
end
