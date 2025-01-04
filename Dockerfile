FROM bitwalker/alpine-elixir:1.16.2 AS base
ENV FFMPEG_PATH=/usr/bin/ffmpeg
ENV YTDL_PATH=/usr/local/bin/yt-dlp
ARG DISCORD_TOKEN
RUN apk add ffmpeg py3-pip gcc libc-dev g++ python3-dev curl
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
RUN chmod a+rx /usr/local/bin/yt-dlp 

COPY mix.exs .
COPY mix.lock .
RUN mix deps.get

COPY lib lib
COPY test test
COPY config config

RUN MIX_ENV=prod mix release
CMD _build/prod/rel/porter/bin/porter start