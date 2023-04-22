#!/bin/bash
/usr/bin/git pull
/usr/bin/docker stop porter
/usr/bin/docker rm -f porter
/usr/bin/docker rmi porter:latest
/usr/bin/docker build . --build-arg DISCORD_TOKEN=$1 -t porter:latest
/usr/bin/docker run --name porter -d porter:latest