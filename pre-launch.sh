#!/bin/bash

docker rm grommunio-volume

docker create grommunio-volume

docker run --name populate-volume -d -v grommunio-volume:/home/vars busybox sleep 3600

docker cp var.env populate-volume:/home/vars

docker stop populate-volume

docker container prune -f
