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
      channel = Channel.get()

      case channel do
        nil ->
          Cogs.say("Define channel name first using !setchannel command")

        _ ->
          _handle_lock(id)
      end
    end

    Cogs.def play(query) do
      {:ok, id} = Cogs.guild_id()
      channel = Channel.get()

      case channel do
        nil ->
          Cogs.say("Define channel name first using !setchannel command")

        _ ->
          {url, name} = Utils.search(query)
          Queue.add({url, name})
          Cogs.say("#{name} - #{url} added")
          _handle_lock(id)
      end
    end

    Cogs.def stop do
      {:ok, id} = Cogs.guild_id()

      StopReason.set_stopped()

      Voice.stop_audio(id)
      {_url, name} = Queue.get()
      Cogs.say("#{name} stopped")
    end

    Cogs.def skip do
      {:ok, id} = Cogs.guild_id()

      StopReason.set_skipped()

      Voice.stop_audio(id)
      {_url, name} = Queue.get()
      Cogs.say("#{name} skipped")
    end

    Cogs.def queue do
      queue = Queue.print_queue()

      msg =
        case queue do
          [] -> "Queue is empty, add a song using !play <query> command!"
          _ -> "Queue:\n #{queue}"
        end

      Cogs.say(msg)
    end

    Cogs.def leave do
      {:ok, id} = Cogs.guild_id()

      case Voice.leave(id) do
        :ok -> nil
        {:error, error} -> Cogs.say("Oops #{error}")
      end
    end

    Cogs.def setchannel(channel_name) do
      Channel.set(channel_name)
      Cogs.say("Channel name set to #{channel_name}")
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
      {:ok, channels} = Client.get_channels(id)
      channel = Channel.get()
      default_voice_channel = Enum.find(channels, &match?(%{name: ^channel}, &1))
      Voice.join(id, default_voice_channel.id)

      queue = Queue.get()

      case queue do
        [] ->
          Lock.unlock()
          nil

        {url, _name} ->
          Voice.play_url(id, url)
          Voice.wait_for_end(id)

          case StopReason.get() do
            :stopped ->
              Lock.unlock()

            :skipped ->
              Queue.remove()

              Lock.unlock()

              _handle_lock(id)

            :finished ->
              Queue.remove()

              Lock.unlock()

              _handle_lock(id)
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
      StopReason,
      Channel
    ]

    {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_all)
    use Commands
    run
  end
end
