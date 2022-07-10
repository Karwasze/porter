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
    children = [AudioPlayerConsumer, Queue, StopReason, Lock]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule AudioPlayerConsumer do
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Voice

  require Logger

  @ended_retries 14400
  @ended_step 1000
  @ready_retries 20
  @ready_step 100

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def initialized?(guild_id) do
    case StopReason.get(guild_id) do
      nil -> false
      _ -> true
    end
  end

  def init_if_new_guild(msg) do
    unless initialized?(msg.guild_id) do
      init_agents(msg)
    end
  end

  def init_agents(msg) do
    Queue.init(msg.guild_id)
    StopReason.init(msg.guild_id)
    Lock.init(msg.guild_id)
    msg.guild_id |> IO.inspect(label: "guild id: ")
  end

  def get_voice_channel_of_interaction(guild_id, user_id) do
    guild_id
    |> GuildCache.get!()
    |> Map.get(:voice_states)
    |> Enum.find(%{}, fn v -> v.user_id == user_id end)
    |> Map.get(:channel_id)
  end

  def wait_for(function, step, retries) do
    for _ <- 0..retries do
      case function.() do
        true -> :ok
        false -> Process.sleep(step)
      end
    end
  end

  def wait_for_end(msg) do
    wait_for(fn -> !Voice.playing?(msg.guild_id) end, @ended_step, @ended_retries)
  end

  def wait_for_join(msg) do
    wait_for(
      fn -> Voice.ready?(msg.guild_id) end,
      @ready_step,
      @ready_retries
    )
  end

  def add_to_queue(msg, query) do
    case query do
      "isolated_special" ->
        song = {"https://www.youtube.com/watch?v=uoUCyrg5Syo", "Chiasm - Isolated"}
        Queue.add(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🦇🦇🦇 **GROŹNY WAMPIREK UWAGA** 🦇🦇🦇")

      "masquerade_special" ->
        song = {"https://www.youtube.com/watch?v=9cAd0noZxH4", "Masquerade violation"}
        Queue.add(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🦇🦇🦇 **MASQUERADE VIOLATION** 🦇🦇🦇")

      "santa_monica_special" ->
        song = {"https://www.youtube.com/watch?v=VuXD3jTDqqU", "Santa Monica Theme"}
        Queue.add(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🦇🦇🦇 **GROŹNY WAMPIREK UWAGA** 🦇🦇🦇")

      "explosion_special" ->
        song = {"https://www.youtube.com/watch?v=4qae2BKuDEQ", "Kalwi & Remi - Explosion"}
        Queue.add(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🧨🧨🧨 **EXPLOSION** 🧨🧨🧨")

      "redline_special" ->
        song = {"https://www.youtube.com/watch?v=doEwWzMz99A", "REDLINE OST - Yellow Line"}
        Queue.add(msg.guild_id, song)
        Api.create_message(msg.channel_id, "🚗🚗🚗 **REDLINE OST** 🚗🚗🚗")

      "drive_special" ->
        song =
          {"https://www.youtube.com/watch?v=-DSVDcw6iW8",
           "College & Electric Youth - A Real Hero (Drive Original Movie Soundtrack)"}

        Queue.add(msg.guild_id, song)
        Api.create_message(msg.channel_id, "**🚗 PRAWDZIWA 🚗 LUDZKA 🚗 FASOLA**")

      "evangelion_special" ->
        song =
          {"https://www.youtube.com/watch?v=zc6KUlXP--M",
           "The End Of Evangelion: Komm, süsser Tod"}

        Queue.add(msg.guild_id, song)
        Api.create_message(msg.channel_id, "**Wskakuj do robota Shinji**")

      "alert_special" ->
        song =
          {"https://www.youtube.com/watch?v=OQiDzSWLIm4", "Metal Gear Solid Music - Alert Phase"}

        Queue.add(msg.guild_id, song)
        Api.create_message(msg.channel_id, "**🔔❗**")

      "alien_special" ->
        song = {"https://www.youtube.com/watch?v=kurAJvAHB6I", "bogos binted?"}

        Queue.add(msg.guild_id, song)
        Api.create_message(msg.channel_id, "**👽**")

      _ ->
        {url, name} = Utils.search(query)
        Queue.add(msg.guild_id, {url, name})
        Api.create_message(msg.channel_id, "ℹ️ **#{name}** added")
    end
  end

  def handle_stop_reason(:stopped, _msg),
    do: nil

  def handle_stop_reason(_, msg) do
    Queue.remove(msg.guild_id)
    Lock.unlock(msg.guild_id)
    handle_lock(msg)
  end

  def play(msg) do
    with {url, name} <- Queue.get(msg.guild_id) do
      Api.create_message(msg.channel_id, "🎶 Now playing **#{name}** - #{url}")
      StopReason.set_finished(msg.guild_id)

      Voice.play(msg.guild_id, url, :ytdl)
      wait_for_end(msg)

      StopReason.get(msg.guild_id)
      |> handle_stop_reason(msg)
    else
      [] ->
        Lock.unlock(msg.guild_id)
    end
  end

  def handle_lock(msg) do
    case Lock.get(msg.guild_id) do
      :locked ->
        nil

      :unlocked ->
        StopReason.set_finished(msg.guild_id)
        Lock.lock(msg.guild_id)
        play(msg)
    end
  end

  def prepare_channel(msg, query \\ nil) do
    voice_channel = get_voice_channel_of_interaction(msg.guild_id, msg.author.id)

    case voice_channel do
      nil ->
        Api.create_message!(
          msg.channel_id,
          "❌ You have to be in a voice channel to play music"
        )

      voice_channel_id ->
        Voice.join_channel(msg.guild_id, voice_channel_id)
        wait_for_join(msg)

        if query do
          add_to_queue(msg, query)
        else
          case StopReason.get(msg.guild_id) do
            :stopped -> Lock.unlock(msg.guild_id)
            :skipped -> Lock.unlock(msg.guild_id)
            _ -> nil
          end
        end

        handle_lock(msg)
    end
  end

  def stop_and_clear_queue(msg) do
    init_if_new_guild(msg)
    Voice.stop(msg.guild_id)
    Queue.remove_all(msg.guild_id)
    Lock.unlock(msg.guild_id)
    StopReason.set_finished(msg.guild_id)
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "!play" ->
        init_if_new_guild(msg)
        prepare_channel(msg)

      "!play" <> query ->
        init_if_new_guild(msg)
        prepare_channel(msg, query)

      "!stop" ->
        init_if_new_guild(msg)
        StopReason.set_stopped(msg.guild_id)
        Voice.stop(msg.guild_id)
        {_url, name} = Queue.get(msg.guild_id)
        Api.create_message(msg.channel_id, "⏹️ **#{name}** stopped")

      "!skip" ->
        init_if_new_guild(msg)
        {_url, name} = Queue.get(msg.guild_id)
        StopReason.set_skipped(msg.guild_id)
        Api.create_message(msg.channel_id, "⏩ **#{name}** skipped")
        playing? = Voice.playing?(msg.guild_id)

        if playing? do
          Voice.stop(msg.guild_id)
        else
          Queue.remove(msg.guild_id)
          handle_lock(msg)
        end

      "!leave" ->
        stop_and_clear_queue(msg)
        Voice.leave_channel(msg.guild_id)

      "!queue" ->
        init_if_new_guild(msg)
        queue = Queue.print_queue(msg.guild_id)

        message =
          case queue do
            [] -> "ℹ️ Queue is empty, add a song using **!play <query>** command!"
            _ -> "__Queue__:\n\n**🔊 Now playing: **#{queue}"
          end

        Api.create_message!(msg.channel_id, message)

      "!help" ->
        init_if_new_guild(msg.guild_id)

        message = """
        Available commands:
        **!play <query>**
        Adds a song to the queue, if the queue is empty it also plays the song.

        **!play**
        Plays the current song in the queue.

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
        stop_and_clear_queue(msg)
        prepare_channel(msg, "isolated_special")

      "!2" ->
        stop_and_clear_queue(msg)
        prepare_channel(msg, "masquerade_special")

      "!3" ->
        stop_and_clear_queue(msg)
        prepare_channel(msg, "santa_monica_special")

      "!4" ->
        stop_and_clear_queue(msg)
        prepare_channel(msg, "explosion_special")

      "!5" ->
        stop_and_clear_queue(msg)
        prepare_channel(msg, "redline_special")

      "!6" ->
        stop_and_clear_queue(msg)
        prepare_channel(msg, "drive_special")

      "!7" ->
        stop_and_clear_queue(msg)
        prepare_channel(msg, "evangelion_special")

      "👽" ->
        stop_and_clear_queue(msg)
        prepare_channel(msg, "alien_special")

      "!alert" ->
        stop_and_clear_queue(msg)
        prepare_channel(msg, "alert_special")

      _ ->
        nil
    end
  end

  def handle_event({:READY, %{guilds: guilds} = _event, _ws_state}) do
    guilds
    |> Enum.map(fn guild -> guild.id end)
    |> Enum.each(&init_agents/1)
  end

  def handle_event(_event) do
    :noop
  end
end
