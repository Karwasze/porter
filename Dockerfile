FROM bitwalker/alpine-elixir:1.13.4
ENV FFMPEG_PATH=/usr/bin/ffmpeg
ENV YTDL_PATH=/usr/bin/yt-dlp
ARG DISCORD_TOKEN
RUN apk add ffmpeg py3-pip gcc libc-dev g++ python3-dev
#RUN apk add yt-dlp=2023.02.17-r0 --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community
RUN python3 -m pip install --no-cache-dir --force-reinstall "yt-dlp>2023"

COPY mix.exs .
COPY mix.lock .
RUN mix deps.get

COPY lib lib
COPY test test
COPY config config

RUN MIX_ENV=prod mix release
CMD _build/prod/rel/porter/bin/porter start