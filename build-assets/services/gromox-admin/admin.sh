#!/usr/bin/with-contenv sh

grommunio-admin passwd -p $ADMIN_PASS 
ln -s /home/plugins/conf.yaml /etc/grommunio-admin-api/conf.d/conf.yaml 
/home/links/config.sh 
ln -s /home/links/web-config.conf /etc/grommunio-admin-common/nginx.d/web-config.conf 
uwsgi --ini /usr/share/grommunio-admin-api/api-config.ini --daemonize /var/log/admin-api.log 
chown nginx:nginx /run/grommunio/admin-api.socket 
