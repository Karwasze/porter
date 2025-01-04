#!/bin/bash
/usr/bin/git pull
/usr/bin/docker build . --no-cache --build-arg DISCORD_TOKEN=$1 -t porter:latest
/usr/bin/docker run --rm --name porter -d porter:latest
/usr/bin/docker image prune -f