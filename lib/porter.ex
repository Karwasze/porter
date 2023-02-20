defmodule AudioPlayerSupervisor do
  use Supervisor

  def start(_mode, args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [AudioPlayerConsumer, State]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule AudioPlayerConsumer do
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Voice

  require Logger

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def add_to_queue(msg, query \\ nil) do
    case query do
      nil ->
        nil

      _ ->
        {url, name} = Utils.search(query)
        State.add_to_queue(msg.guild_id, {url, name})
        Api.create_message(msg.channel_id, "ℹ️ **#{name}** added")
    end
  end

  def add_to_queue_special(msg, query) do
    case query do
      "isolated_special" ->
        song = {"https://www.youtube.com/watch?v=uoUCyrg5Syo", "Chiasm - Isolated"}
        State.add_to_queue(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🦇🦇🦇 **GROŹNY WAMPIREK UWAGA** 🦇🦇🦇")

      "masquerade_special" ->
        song = {"https://www.youtube.com/watch?v=9cAd0noZxH4", "Masquerade violation"}
        State.add_to_queue(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🦇🦇🦇 **MASQUERADE VIOLATION** 🦇🦇🦇")

      "santa_monica_special" ->
        song = {"https://www.youtube.com/watch?v=VuXD3jTDqqU", "Santa Monica Theme"}
        State.add_to_queue(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🦇🦇🦇 **GROŹNY WAMPIREK UWAGA** 🦇🦇🦇")

      "explosion_special" ->
        song = {"https://www.youtube.com/watch?v=4qae2BKuDEQ", "Kalwi & Remi - Explosion"}
        State.add_to_queue(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🧨🧨🧨 **EXPLOSION** 🧨🧨🧨")

      "redline_special" ->
        song = {"https://www.youtube.com/watch?v=doEwWzMz99A", "REDLINE OST - Yellow Line"}
        State.add_to_queue(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🚗🚗🚗 **REDLINE OST** 🚗🚗🚗")

      "drive_special" ->
        song =
          {"https://www.youtube.com/watch?v=-DSVDcw6iW8",
           "College & Electric Youth - A Real Hero (Drive Original Movie Soundtrack)"}

        State.add_to_queue(msg.guild_id, song)
        Api.create_message(msg.channel_id, "**🚗 PRAWDZIWA 🚗 LUDZKA 🚗 FASOLA**")

      "evangelion_special" ->
        song =
          {"https://www.youtube.com/watch?v=zc6KUlXP--M",
           "The End Of Evangelion: Komm, süsser Tod"}

        State.add_to_queue(msg.guild_id, song)
        Api.create_message(msg.channel_id, "**Wskakuj do robota Shinji**")

      "alert_special" ->
        song =
          {"https://www.youtube.com/watch?v=OQiDzSWLIm4", "Metal Gear Solid Music - Alert Phase"}

        State.add_to_queue(msg.guild_id, song)
        Api.create_message(msg.channel_id, "**🔔❗**")

      "alien_special" ->
        song = {"https://www.youtube.com/watch?v=kurAJvAHB6I", "bogos binted?"}

        State.add_to_queue(msg.guild_id, song)
        Api.create_message(msg.channel_id, "**👽**")

      _ ->
        {url, name} = Utils.search(query)
        State.add_to_queue(msg.guild_id, {url, name})
        Api.create_message(msg.channel_id, "ℹ️ **#{name}** added")
    end
  end

  def add_to_queue_from_playlist(msg, query) do
    {url, name} = Utils.search(query)
    State.add_to_queue(msg.guild_id, {url, name})
  end

  def handle_stop_reason(:stopped, _msg),
    do: nil

  def handle_stop_reason(_, msg) do
    State.remove_from_queue(msg.guild_id)
    State.unlock(msg.guild_id)
    handle_lock(msg)
  end

  def play(msg) do
    with {url, name} <- State.get_song_from_queue(msg.guild_id) do
      Api.create_message(msg.channel_id, "🎶 Now playing **#{name}** - #{url}")
      State.set_finished(msg.guild_id)
      filters = Utils.get_filters(msg.guild_id)

      if filters != "" do
        Voice.play(msg.guild_id, url, :ytdl, realtime: false, filter: filters)
      else
        Voice.play(msg.guild_id, url, :ytdl)
      end

      Utils.wait_for_end(msg.guild_id)

      State.get_stop_reason(msg.guild_id)
      |> handle_stop_reason(msg)
    else
      [] ->
        State.unlock(msg.guild_id)
    end
  end

  def handle_lock(msg) do
    case State.get_lock(msg.guild_id) do
      :locked ->
        nil

      :unlocked ->
        State.set_finished(msg.guild_id)
        State.lock(msg.guild_id)
        play(msg)
    end
  end

  def prepare_channel(msg, query \\ nil, is_special \\ false) do
    Utils.join_voice_channel(msg)

    if query do
      case State.get_stop_reason(msg.guild_id) do
        :stopped -> State.unlock(msg.guild_id)
        :skipped -> State.unlock(msg.guild_id)
        _ -> nil
      end
    end

    case is_special do
      true ->
        add_to_queue_special(msg, query)
        handle_lock(msg)

      false ->
        add_to_queue(msg, query)
        handle_lock(msg)
    end
  end

  def prepare_channel_playlist(msg, playlist) do
    Utils.join_voice_channel(msg)

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
        handle_lock(msg)

      :error ->
        Api.create_message!(
          msg.channel_id,
          "❌ Failed to decode playlist in base64 format."
        )
    end
  end

  def handle_misc_params(msg) do
    case msg.content do
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

        **!nightcore**
        Adds a nightcore filter

        **!bassboost**
        Adds a bassboost mode

        **!filters**
        Shows currently applied filters

        **!remove_filters
        Removes all filters

        **!stop**
        Stops the current song. This command does **not** remove the song from the queue.

        **!skip**
        Skips the current song.

        **!queue**
        Shows current songs in the queue.

        **!leave**
        Removes Porter from the audio channel.

        **!1**
        Plays **Chiasm - Isolated**

        **!2**
        Plays **Masquerade Violation**

        **!3**
        Plays **Santa Monica Theme Violation**

        **!4**
        Plays **Kalwi & Remi - Explosion**

        **!5**
        Plays **REDLINE OST - Yellow Line**

        **!6**
        Plays **College & Electric Youth - A Real Hero**

        **!7**
        Plays **The End Of Evangelion: Komm, süsser Tod**

        **!alert**
        Plays **Metal Gear Solid Music - Alert Phase**
        """

        Api.create_message!(msg.channel_id, message)

      "!1" ->
        Utils.stop_and_clear_queue(msg)
        prepare_channel(msg, "isolated_special", true)

      "!2" ->
        Utils.stop_and_clear_queue(msg)
        prepare_channel(msg, "masquerade_special", true)

      "!3" ->
        Utils.stop_and_clear_queue(msg)
        prepare_channel(msg, "santa_monica_special", true)

      "!4" ->
        Utils.stop_and_clear_queue(msg)
        prepare_channel(msg, "explosion_special", true)

      "!5" ->
        Utils.stop_and_clear_queue(msg)
        prepare_channel(msg, "redline_special", true)

      "!6" ->
        Utils.stop_and_clear_queue(msg)
        prepare_channel(msg, "drive_special", true)

      "!7" ->
        Utils.stop_and_clear_queue(msg)
        prepare_channel(msg, "evangelion_special", true)

      "👽" ->
        Utils.stop_and_clear_queue(msg)
        prepare_channel(msg, "alien_special", true)

      "!alert" ->
        Utils.stop_and_clear_queue(msg)
        prepare_channel(msg, "alert_special", true)

      _ ->
        nil
    end
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "!playlist" <> playlist ->
        Utils.init_if_new_guild(msg.guild_id)
        prepare_channel_playlist(msg, playlist)

      "!play" ->
        Utils.init_if_new_guild(msg.guild_id)
        prepare_channel(msg)

      "!play" <> query ->
        Utils.init_if_new_guild(msg.guild_id)
        prepare_channel(msg, query)

      "!stop" ->
        Utils.init_if_new_guild(msg.guild_id)
        State.set_stopped(msg.guild_id)
        Voice.stop(msg.guild_id)
        {_url, name} = State.get_song_from_queue(msg.guild_id)
        Api.create_message(msg.channel_id, "⏹️ **#{name}** stopped")

      "!skip" ->
        Utils.init_if_new_guild(msg.guild_id)
        {_url, name} = State.get_song_from_queue(msg.guild_id)
        State.set_skipped(msg.guild_id)
        Api.create_message(msg.channel_id, "⏩ **#{name}** skipped")
        playing? = Voice.playing?(msg.guild_id)

        if playing? do
          Voice.stop(msg.guild_id)
        else
          State.remove_from_queue(msg.guild_id)
          handle_lock(msg)
        end

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
        queue = State.print_queue(msg.guild_id)

        message =
          case queue do
            [] -> "ℹ️ Queue is empty, add a song using **!play <query>** command!"
            _ -> "__Queue__:\n\n**🔊 Now playing: **#{queue}"
          end

        Api.create_message!(msg.channel_id, message)

      "!nightcore" ->
        State.add_filter(msg.guild_id, :nightcore)
        Api.create_message(msg.channel_id, "**Nightcore mode enabled**")

      "!bassboost" ->
        State.add_filter(msg.guild_id, :bassboost)
        Api.create_message(msg.channel_id, "**BassBoost mode enabled**")

      "!filters" ->
        filters = State.get_filters(msg.guild_id)
        Api.create_message(msg.channel_id, "**Current filters:** #{Enum.join(filters, ", ")}")

      "!remove_filters" ->
        State.remove_all_filters(msg.guild_id)
        Api.create_message(msg.channel_id, "**Removed all filters!**")

      _ ->
        handle_misc_params(msg)
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
