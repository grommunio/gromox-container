FROM olam1k0/grommunio:latest

RUN groupadd grommunio && apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y grommunio-web nginx && \
      mkdir /run/php-fpm

COPY   ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 

COPY ./config_files/grom_web_supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY ./shell_files/db.sh /scripts/

EXPOSE 80 443 10080 10443

ENTRYPOINT ["/usr/bin/supervisord"]

