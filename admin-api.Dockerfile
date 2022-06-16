FROM olam1k0/grommunio:latest

RUN apt-get update && apt-get -y install grommunio-admin-api

COPY ./config_files/admin_api_supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 

ENTRYPOINT ["/usr/bin/supervisord"]

# Don't forget to start php-fpm in supervisor file

