FROM elixir:1.13.4
ENV FFMPEG_PATH=/usr/bin/ffmpeg
ENV YTDL_PATH=/usr/bin/yt-dlp
ARG DISCORD_TOKEN
RUN apt update
RUN apt -y install ffmpeg 
RUN wget https://github.com/yt-dlp/yt-dlp/releases/download/2023.02.17/yt-dlp_linux
RUN mv yt-dlp_linux /usr/bin/yt-dlp
RUN chmod 755 /usr/bin/yt-dlp

COPY mix.exs .
COPY mix.lock .
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get --force

COPY lib lib
COPY test test
COPY config config

RUN MIX_ENV=prod mix release
CMD _build/prod/rel/porter/bin/porter start