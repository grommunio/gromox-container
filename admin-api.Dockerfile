FROM olam1k0/grommunio:latest

RUN apt-get update && apt-get -y install nginx grommunio-admin-api grommunio-admin-web 

COPY ./shell_files/db.sh ./shell_files/admin-db.sh /scripts/

COPY   ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 

COPY ./config_files/admin_api_supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY ./config_files/admin_web_config.json /usr/share/grommunio-admin-web/config.json

COPY ./config_files/admin_api_redis.yaml /etc/grommunio-admin-api/conf.d/redis.yaml

RUN chown root:gromox /etc/gromox && \ 
    chmod 775 /etc/gromox && \
    ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf && \
    mkdir /run/grommunio/ 

EXPOSE 8443 11334 

ENTRYPOINT ["/usr/bin/supervisord"]

