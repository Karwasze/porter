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

  def init_queue(guild_id) do
    Queue.init(guild_id)
    StopReason.init(guild_id)
    Lock.init(guild_id)
    guild_id |> IO.inspect(label: "guild id: ")
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
    {url, name} = Utils.search(query)
    Queue.add(msg.guild_id, {url, name})
    Api.create_message(msg.channel_id, "ℹ️ **#{name}** added")
  end

  def handle_stop_reason(:stopped, _msg),
    # do: Lock.unlock(msg.guild_id)
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
        nil
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

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "!play" ->
        prepare_channel(msg)

      "!play" <> query ->
        prepare_channel(msg, query)

      "!stop" ->
        StopReason.set_stopped(msg.guild_id)
        Voice.stop(msg.guild_id)
        {_url, name} = Queue.get(msg.guild_id)
        Api.create_message(msg.channel_id, "⏹️ **#{name}** stopped")

      "!skip" ->
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
        StopReason.set_stopped(msg.guild_id)
        Voice.stop(msg.guild_id)
        Queue.remove_all(msg.guild_id)
        Voice.leave_channel(msg.guild_id)

      "!queue" ->
        queue = Queue.print_queue(msg.guild_id)

        message =
          case queue do
            [] -> "ℹ️ Queue is empty, add a song using **!play <query>** command!"
            _ -> "__Queue__:\n\n**🔊 Now playing: **#{queue}"
          end

        Api.create_message!(msg.channel_id, message)

      _ ->
        :ignore
    end
  end

  def handle_event({:READY, %{guilds: guilds} = _event, _ws_state}) do
    guilds
    |> Enum.map(fn guild -> guild.id end)
    |> Enum.each(&init_queue/1)
  end

  def handle_event(_event) do
    :noop
  end
end
