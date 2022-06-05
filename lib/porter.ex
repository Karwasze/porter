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
      Voice.play_url(id, Queue.get())
    end

    Cogs.def play(query) do
      {:ok, id} = Cogs.guild_id()
      {:ok, url} = Utils.search(query)
      {:ok, channel} = Client.get_channels(id)
      Queue.add(url)
      default_voice_channel = Enum.find(channel, &match?(%{name: "General"}, &1))
      Voice.join(id, default_voice_channel.id)
      _play(id)
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
      end
    end

    Cogs.def stop do
      {:ok, id} = Cogs.guild_id()
      Voice.stop_audio(id)
    end

    Cogs.def skip do
      {:ok, id} = Cogs.guild_id()
      Voice.stop_audio(id)
      song_name = Queue.get()
      Queue.remove()
      Cogs.say("#{song_name} skipped")
      _play(id)
    end

    Cogs.def queue do
      queue = Queue.get_all()

      msg =
        case queue do
          [] -> "Queue is empty, add a song using !play <query> command!"
          _ -> "Now playing #{queue}"
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
  end

  def start(_type, _args) do
    token = Application.fetch_env!(:porter, :discord_token)
    Queue.start_link()
    run = Client.start(token)
    use Commands
    run
  end
end
