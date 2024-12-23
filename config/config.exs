import Config

config :nostrum,
  token: System.get_env("DISCORD_TOKEN"),
  ffmpeg: System.get_env("FFMPEG_PATH") || "/opt/homebrew/opt/ffmpeg@4/bin/ffmpeg",
  youtubedl: System.get_env("YTDL_PATH") || "/usr/local/bin/yt-dlp",
  gateway_intents: [:guilds, :message_content, :guild_messages, :guild_voice_states],
  log_full_events: true
