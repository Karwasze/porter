import Config

config :porter,
  discord_token: System.get_env("DISCORD_TOKEN")

config :alchemy,
  ffmpeg_path: System.get_env("FFMPEG_PATH") || "/opt/homebrew/bin/ffmpeg",
  youtube_dl_path: System.get_env("YTDL_PATH") || "/usr/local/bin/yt-dlp"
