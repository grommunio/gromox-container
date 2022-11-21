#!/usr/bin/with-contenv sh

uwsgi --ini /usr/share/grommunio-admin-api/api-config.ini #--daemonize /var/log/admin-api.log 
chown nginx:nginx /run/grommunio/admin-api.socket 
