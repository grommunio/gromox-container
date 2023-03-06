#!/usr/bin/with-contenv sh

sed -i 's/chmod-socket = 660/chmod-socket = 666/g' /usr/share/grommunio-admin-api/api-config.ini

uwsgi --ini /usr/share/grommunio-admin-api/api-config.ini 
