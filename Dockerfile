FROM elixir:1.18.1-alpine AS build

ENV FFMPEG_PATH=/usr/bin/ffmpeg
ENV YTDL_PATH=/usr/local/bin/yt-dlp

ARG DISCORD_TOKEN

WORKDIR /app

RUN apk add --no-cache \
    git ffmpeg gcc libc-dev g++ python3-dev curl bash

RUN mix local.rebar --force
RUN mix local.hex --force

RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
RUN chmod a+rx /usr/local/bin/yt-dlp

COPY mix.exs mix.lock ./

RUN mix deps.get --only prod

COPY lib lib
COPY test test
COPY config config

RUN MIX_ENV=prod mix release
CMD _build/prod/rel/porter/bin/porter start