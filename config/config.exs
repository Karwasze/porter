import Config

config :porter,
  discord_token: System.get_env("DISCORD_TOKEN")

config :alchemy,
  ffmpeg_path: "/opt/homebrew/bin/ffmpeg",
  youtube_dl_path: "/usr/local/bin/yt-dlp"
