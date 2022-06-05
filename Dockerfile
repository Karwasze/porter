FROM bitwalker/alpine-elixir:1.13.4
ENV FFMPEG_PATH=/usr/bin/ffmpeg
ENV YTDL_PATH=/usr/bin/yt-dlp
RUN apk add ffmpeg yt-dlp

COPY mix.exs .
COPY mix.lock .
RUN mix deps.get

COPY lib lib
COPY test test
COPY config config

RUN MIX_ENV=prod mix release
CMD _build/prod/rel/porter/bin/porter start
