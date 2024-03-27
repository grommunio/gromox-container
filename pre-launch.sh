#!/bin/bash

docker volume rm variables_data

docker volume create variables_data

docker run --name populate-volume -d -v variables_data:/home/vars busybox sleep 3600

docker cp var.env populate-volume:/home/vars

docker stop populate-volume

docker container prune -f
