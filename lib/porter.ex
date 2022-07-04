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

      channel = Channel.get(id)

      case channel do
        nil ->
          Cogs.say("Define channel name first using !setchannel command")

        _ ->
          _handle_lock(id)
      end
    end

    Cogs.def play(query) do
      {:ok, id} = Cogs.guild_id()

      channel = Channel.get(id)

      case channel do
        nil ->
          Cogs.say("Define channel name first using !setchannel command")

        _ ->
          {url, name} = Utils.search(query)

          Queue.add(id, {url, name})
          id |> IO.inspect()

          Cogs.say("#{name} - #{url} added")
          _handle_lock(id)
      end
    end

    Cogs.def stop do
      {:ok, id} = Cogs.guild_id()

      StopReason.set_stopped(id)

      Voice.stop_audio(id)
      {_url, name} = Queue.get(id)
      Cogs.say("#{name} stopped")
    end

    Cogs.def skip do
      {:ok, id} = Cogs.guild_id()

      StopReason.set_skipped(id)

      Voice.stop_audio(id)
      {_url, name} = Queue.get(id)
      Cogs.say("#{name} skipped")
    end

    Cogs.def queue do
      {:ok, id} = Cogs.guild_id()
      queue = Queue.print_queue(id)

      msg =
        case queue do
          [] -> "Queue is empty, add a song using !play <query> command!"
          _ -> "Queue:\n#{queue}"
        end

      Cogs.say(msg)
    end

    Cogs.def leave do
      {:ok, id} = Cogs.guild_id()
      Voice.stop_audio(id)
      Queue.remove_all(id)
      Voice.leave(id)
    end

    Cogs.def setchannel(channel_name) do
      {:ok, id} = Cogs.guild_id()
      Queue.init(id)
      Lock.init(id)
      StopReason.init(id)
      Channel.set(id, channel_name)
      Cogs.say("Channel name set to #{channel_name}")
    end

    defp _handle_lock(id) do
      case Lock.get(id) do
        :locked ->
          nil

        :unlocked ->
          StopReason.set_finished(id)
          Lock.lock(id)

          _play(id)
      end
    end

    defp _play(id) do
      {:ok, channels} = Client.get_channels(id)
      channel = Channel.get(id)
      default_voice_channel = Enum.find(channels, &match?(%{name: ^channel}, &1))
      Voice.join(id, default_voice_channel.id)

      queue = Queue.get(id)

      case queue do
        [] ->
          Lock.unlock(id)
          nil

        {url, _name} ->
          Voice.play_url(id, url)
          Voice.wait_for_end(id)

          case StopReason.get(id) do
            :stopped ->
              Lock.unlock(id)

            :skipped ->
              Queue.remove(id)

              Lock.unlock(id)

              _handle_lock(id)

            :finished ->
              Queue.remove(id)

              Lock.unlock(id)

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
