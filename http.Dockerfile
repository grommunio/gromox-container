FROM olam1k0/grommunio:latest

COPY ./config_files/http_supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 10080 10443

ENTRYPOINT ["/usr/bin/supervisord"]

