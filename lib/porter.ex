defmodule Porter do
  use Application
  alias Alchemy.Client

  defmodule Commands do
    use Alchemy.Cogs
    alias Alchemy.Voice
    alias Alchemy.Client
    Cogs.set_parser(:play, &List.wrap/1)

    Cogs.def play(query) do
      {:ok, id} = Cogs.guild_id()
      {:ok, url} = Utils.search(query)
      Voice.stop_audio(id)
      {:ok, channel} = Client.get_channels(id)
      default_voice_channel = Enum.find(channel, &match?(%{name: "General"}, &1))
      Voice.join(id, default_voice_channel.id)
      Voice.play_url(id, url)
      Cogs.say("Now playing #{url}")
    end

    Cogs.def stop do
      {:ok, id} = Cogs.guild_id()
      Voice.stop_audio(id)
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

    run = Client.start(token)
    use Commands
    run
  end
end
