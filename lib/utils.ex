defmodule Utils do
  @ended_retries 14400
  @ended_step 1000
  @ready_retries 20
  @ready_step 100

  alias Nostrum.Api
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Voice
  require Logger

  def search(query) do
    case System.cmd("yt-dlp", [
           "ytsearch:#{query}",
           "--flat-playlist",
           "--print",
           "url",
           "--print",
           "filename"
         ]) do
      {result, 0} ->
        result = String.split(result, ~r{\n}, trim: true)
        url = List.first(result)

        name =
          List.last(result)
          |> String.split(" ")
          |> List.delete_at(-1)
          |> Enum.join(" ")

        {url, name}

      {error, _} ->
        {:err, error}
    end
  end

  def initialized?(guild_id) do
    case StopReason.get(guild_id) do
      nil -> false
      _ -> true
    end
  end

  def init_if_new_guild(guild_id) do
    unless initialized?(guild_id) do
      init_agents(guild_id)
    end
  end

  def init_agents(guild_id) do
    Queue.init(guild_id)
    StopReason.init(guild_id)
    Lock.init(guild_id)
    Filters.init(guild_id)
    Logger.info("Guild ID: #{guild_id}")
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

  def wait_for_end(guild_id) do
    wait_for(fn -> !Voice.playing?(guild_id) end, @ended_step, @ended_retries)
  end

  def wait_for_join(guild_id) do
    wait_for(
      fn -> Voice.ready?(guild_id) end,
      @ready_step,
      @ready_retries
    )
  end

  def stop_and_clear_queue(msg) do
    init_if_new_guild(msg.guild_id)
    Voice.stop(msg.guild_id)
    Queue.remove_all(msg.guild_id)
    Lock.unlock(msg.guild_id)
    StopReason.set_finished(msg.guild_id)
  end

  def join_voice_channel(msg, api_message \\ "❌ You have to be in a voice channel to play music") do
    voice_channel = Utils.get_voice_channel_of_interaction(msg.guild_id, msg.author.id)

    case voice_channel do
      nil ->
        Api.create_message!(
          msg.channel_id,
          api_message
        )

      voice_channel_id ->
        Voice.join_channel(msg.guild_id, voice_channel_id)
        Utils.wait_for_join(msg.guild_id)
    end
  end

  def convert_atom_to_filter(atom) do
    case atom do
      :nightcore -> "atempo=1.06,asetrate=44100*1.25"
      :bassboost -> "bass=g=3"
    end
  end

  def get_filters(id) do
    filters = Filters.get_all(id)

    Enum.map_join(filters, fn filter -> convert_atom_to_filter(filter) end, ",")
  end
end
