defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [AudioPlayerConsumer, Queue, StopReason, Lock, Filters]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule AudioPlayerConsumer do
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Voice

  require Logger

  def add_to_queue(msg, query) do
    Logger.info("Adding to queue - message: #{msg.content}, query: #{query}")
    {url, name} = Utils.search(query)
    Queue.add(msg.guild_id, {url, name})
    Api.create_message(msg.channel_id, "ℹ️ **#{name}** added")
  end

  def add_to_queue_from_playlist(msg, query) do
    Logger.info("Adding to queue from playlist - message: #{msg.content}, query: #{query}")
    {url, name} = Utils.search(query)
    Queue.add(msg.guild_id, {url, name})
  end

  def handle_stop_reason(:stopped, _msg) do
    Logger.info("Handling stop reason: stopped")
  end

  def handle_stop_reason(_, msg) do
    Logger.info("Handling stop reason: other")
    Queue.remove(msg.guild_id)
    Lock.unlock(msg.guild_id)
    play_if_possible(msg)
  end

  def play(msg) do
    with {url, name} <- Queue.get(msg.guild_id) do
      Api.create_message(msg.channel_id, "🎶 Now playing **#{name}** - #{url}")
      StopReason.set_finished(msg.guild_id)
      Logger.info("Getting filters")
      filters = Utils.get_filters(msg.guild_id)

      if filters != "" do
        Logger.info("Playing with filters: #{filters}")

        case Voice.play(msg.guild_id, url, :ytdl, realtime: false, filter: filters) do
          :ok -> Logger.info("Voice.play() successful")
          {:error, reason} -> Logger.error("Voice.play() unsuccessful, #{reason}")
        end
      else
        Logger.info("Playing without filters")

        case Voice.play(msg.guild_id, "./test.mp3", :url) do
          :ok -> Logger.info("Voice.play() successful #{msg.guild_id}, #{url}")
          {:error, reason} -> Logger.error("Voice.play() unsuccessful, #{reason}")
        end
      end

      Logger.info("Waiting for end")
      Utils.wait_for_end(msg.guild_id)

      StopReason.get(msg.guild_id)
      |> handle_stop_reason(msg)
    else
      [] ->
        Lock.unlock(msg.guild_id)
    end
  end

  def play_if_possible(msg) do
    case Lock.get(msg.guild_id) do
      :locked ->
        Logger.info("Lock is locked for #{msg.guild_id}")

      :unlocked ->
        Logger.info("Lock is unlocked for #{msg.guild_id}")
        Logger.info("Setting StopReason to finished for #{msg.guild_id}")
        StopReason.set_finished(msg.guild_id)
        Logger.info("Locking lock for #{msg.guild_id}")
        Lock.lock(msg.guild_id)
        Logger.info("Checking if voice is playing for #{msg.guild_id}")

        case Voice.playing?(msg.guild_id) do
          true ->
            Logger.info("Voice is already playing for #{msg.guild_id}")

          false ->
            Logger.info("Running play(msg) for #{msg.guild_id}")
            play(msg)
        end
    end
  end

  def add_playlist(msg, playlist) do
    playlist = playlist |> String.trim()

    case Base.decode64(playlist) do
      {:ok, decoded_playlist} ->
        [playlist_name | decoded_playlist] =
          decoded_playlist
          |> String.split("\n")

        Api.create_message!(
          msg.channel_id,
          "ℹ️ Processing **#{playlist_name}** playlist (it may take a while)."
        )

        Enum.each(decoded_playlist, fn url -> add_to_queue_from_playlist(msg, url) end)
        Api.create_message(msg.channel_id, "ℹ️ **#{playlist_name}** added")

      :error ->
        Api.create_message!(
          msg.channel_id,
          "❌ Failed to decode playlist in base64 format."
        )
    end
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "!playlist" <> playlist ->
        Utils.init_if_new_guild(msg.guild_id)
        Utils.join_voice_channel(msg)
        add_playlist(msg, playlist)
        play_if_possible(msg)

      "!play" ->
        Utils.init_if_new_guild(msg.guild_id)
        Utils.join_voice_channel(msg)

        case StopReason.get(msg.guild_id) do
          :stopped -> Lock.unlock(msg.guild_id)
          :skipped -> Lock.unlock(msg.guild_id)
          _ -> nil
        end

        play_if_possible(msg)

      "!play" <> query ->
        Utils.init_if_new_guild(msg.guild_id)
        Utils.join_voice_channel(msg)
        add_to_queue(msg, query)
        play_if_possible(msg)

      "!stop" ->
        Utils.init_if_new_guild(msg.guild_id)
        StopReason.set_stopped(msg.guild_id)
        Voice.stop(msg.guild_id)
        {_url, name} = Queue.get(msg.guild_id)
        Api.create_message(msg.channel_id, "⏹️ **#{name}** stopped")

      "!skip" ->
        Utils.init_if_new_guild(msg.guild_id)
        {_url, name} = Queue.get(msg.guild_id)
        StopReason.set_skipped(msg.guild_id)
        Api.create_message(msg.channel_id, "⏩ **#{name}** skipped")
        playing? = Voice.playing?(msg.guild_id)

        if playing? do
          Voice.stop(msg.guild_id)
        else
          Queue.remove(msg.guild_id)
          play_if_possible(msg)
        end

      "!nightcore" ->
        Filters.add(msg.guild_id, :nightcore)
        Api.create_message(msg.channel_id, "**Nightcore mode enabled**")

      "!bassboost" ->
        Filters.add(msg.guild_id, :bassboost)
        Api.create_message(msg.channel_id, "**BassBoost mode enabled**")

      "!filters" ->
        filters = Filters.get_all(msg.guild_id)
        Api.create_message(msg.channel_id, "**Current filters:** #{Enum.join(filters, ", ")}")

      "!remove_filters" ->
        Filters.remove_all(msg.guild_id)
        Api.create_message(msg.channel_id, "**Removed all filters!**")

      "!leave" ->
        Utils.join_voice_channel(
          msg,
          "❌ You have to be in the same voice channel as bot to leave"
        )

        Utils.stop_and_clear_queue(msg)
        Voice.leave_channel(msg.guild_id)
        Api.create_message!(msg.channel_id, "ℹ️ Leaving voice channel")

      "!queue" ->
        Utils.init_if_new_guild(msg.guild_id)
        queue = Queue.print_queue(msg.guild_id)

        message =
          case queue do
            [] -> "ℹ️ Queue is empty, add a song using **!play <query>** command!"
            _ -> "__Queue__:\n\n**🔊 Now playing: **#{queue}"
          end

        Api.create_message!(msg.channel_id, message)

      "!help" ->
        Utils.init_if_new_guild(msg.guild_id)

        message = """
        Available commands:
        **!play <query>**
        Adds a song to the queue, if the queue is empty it also plays the song.

        **!play**
        Plays the current song in the queue.

        **!playlist <playlist>**
        Adds a prepared playlist to the queue. A playlist is a base64 encoded string comprised of a title and YouTube urls separated by newlines. Example:
        RXhhbXBsZQpodHRwczovL3d3dy55b3V0dWJlLmNvbS93YXRjaD92PWRRdzR3OVdnWGNR

        **!stop**
        Stops the current song. This command does **not** remove the song from the queue.

        **!skip**
        Skips the current song.

        **!queue**
        Shows current songs in the queue.

        **!leave**
        Removes Porter from the audio channel.

        **!nightcore**
        Adds a nightcore filter

        **!bassboost**
        Adds a bassboost mode

        **!filters**
        Shows currently applied filters

        **!remove_filters
        Removes all filters
        """

        Api.create_message!(msg.channel_id, message)

      "!test" ->
        Logger.info("Creating test message")
        Api.create_message!(msg.channel_id, "Test")
        Logger.info("Joining new guild")
        Utils.init_if_new_guild(msg.guild_id)
        Logger.info("Joining voice channel")
        Utils.join_voice_channel(msg)

        case Nostrum.Voice.ready?(msg.guild_id) do
          true -> Logger.info("Voice ready")
          false -> Logger.info("Voice not ready")
        end

        case Voice.play(
               msg.guild_id,
               "https://file-examples.com/storage/fefaeec240676402c9bdb74/2017/11/file_example_MP3_700KB.mp3",
               :url,
               volume: 10
             ) do
          :ok -> Logger.info("Playing succeeded")
          {:error, reason} -> Logger.info("Playing failed: #{reason}")
        end

      _ ->
        nil
    end
  end

  def handle_event({:READY, %{guilds: guilds} = _event, _ws_state}) do
    guilds
    |> Enum.map(fn guild -> guild.id end)
    |> Enum.each(&Utils.init_agents/1)
  end

  def handle_event(_event) do
    :noop
  end
end
