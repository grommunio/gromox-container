#!/bin/sh -e

redis-server --daemonize yes
rspamd -u groas -g grommunio 
