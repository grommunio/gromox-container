FROM olam1k0/grommunio:latest

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y grommunio-web nginx

COPY ./config_files/grom_web_supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY ./shell_files/db.sh /scripts/

EXPOSE 80 443 10080 10443

ENTRYPOINT ["/usr/bin/supervisord"]

