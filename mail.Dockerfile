FROM olam1k0/grommunio:latest

COPY ./config_files/mail_supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 993 995 5555 33333 

ENTRYPOINT ["/usr/bin/supervisord"]

