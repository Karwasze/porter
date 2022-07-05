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
    children = [AudioPlayerConsumer, Queue, StopReason]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule AudioPlayerConsumer do
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Voice

  require Logger

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def init_queue(guild_id) do
    Queue.init(guild_id)
    guild_id |> IO.inspect(label: "guild id: ")
  end

  def get_voice_channel_of_interaction(guild_id, user_id) do
    guild_id
    |> GuildCache.get!()
    |> Map.get(:voice_states)
    |> Enum.find(%{}, fn v -> v.user_id == user_id end)
    |> Map.get(:channel_id)
  end

  def wait_for_join(msg) do
    Process.sleep(100)
    ready? = Voice.ready?(msg.guild_id)

    if ready? do
      :ok
    else
      wait_for_join(msg)
    end
  end

  def wait_for_end(msg) do
    Process.sleep(1000)

    playing? = Voice.playing?(msg.guild_id)

    if playing? do
      wait_for_end(msg)
    else
      :ok
    end
  end

  def handle_lock(msg) do
    if Voice.playing?(msg.guild_id) do
      nil
    else
      play(msg)
    end
  end

  def play(msg) do
    queue = Queue.get(msg.guild_id)

    case queue do
      [] ->
        nil

      {url, _name} ->
        Voice.play(msg.guild_id, url, :ytdl)
        wait_for_end(msg)

        case StopReason.get(msg.guild_id) do
          :stopped ->
            nil

          :skipped ->
            Queue.remove(msg.guild_id)
            play(msg)

          :finished ->
            Queue.remove(msg.guild_id)
            play(msg)
        end
    end
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "!play" ->
        case get_voice_channel_of_interaction(msg.guild_id, msg.author.id) do
          nil ->
            Api.create_message!(msg.channel_id, "You must be in a voice channel to summon me")

          voice_channel ->
            Voice.join_channel(msg.guild_id, voice_channel)
            wait_for_join(msg)
            handle_lock(msg)
        end

      "!play" <> query ->
        case get_voice_channel_of_interaction(msg.guild_id, msg.author.id) do
          nil ->
            Api.create_message!(msg.channel_id, "You must be in a voice channel to summon me")

          voice_channel ->
            Voice.join_channel(msg.guild_id, voice_channel)
            wait_for_join(msg)
            {url, name} = Utils.search(query)
            Queue.add(msg.guild_id, {url, name})
            Api.create_message(msg.channel_id, "#{name} - #{url} added")
            handle_lock(msg)
        end

      "!stop" ->
        StopReason.set_stopped(msg.guild_id)
        Voice.stop(msg.guild_id)
        {_url, name} = Queue.get(msg.guild_id)
        Api.create_message(msg.channel_id, "#{name} stopped")

      "!skip" ->
        StopReason.set_skipped(msg.guild_id)
        Voice.stop(msg.guild_id)
        {_url, name} = Queue.get(msg.guild_id)
        Api.create_message(msg.channel_id, "#{name} skipped")

      "!leave" ->
        StopReason.set_stopped(msg.guild_id)
        Voice.stop(msg.guild_id)
        Queue.remove_all(msg.guild_id)
        Voice.leave_channel(msg.guild_id)

      "!queue" ->
        queue = Queue.print_queue(msg.guild_id)

        message =
          case queue do
            [] -> "Queue is empty"
            _ -> "Queue:\n#{queue}"
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
