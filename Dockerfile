FROM bitwalker/alpine-elixir:1.13.4 AS base
ENV FFMPEG_PATH=/usr/bin/ffmpeg
ENV YTDL_PATH=/usr/bin/yt-dlp
ARG DISCORD_TOKEN
RUN apk add ffmpeg==4.4.5 py3-pip gcc libc-dev g++ python3-dev
RUN python3 -m pip install --no-cache-dir --force-reinstall "yt-dlp>2024"

COPY mix.exs .
COPY mix.lock .
RUN mix deps.get

COPY lib lib
COPY test test
COPY config config

RUN MIX_ENV=prod mix release
CMD _build/prod/rel/porter/bin/porter start