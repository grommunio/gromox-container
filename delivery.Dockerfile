FROM olam1k0/grommunio:latest

RUN DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y postfix postfix-mysql

RUN postconf -e virtual_alias_maps=mysql:/etc/postfix/g-alias.cf && \
    postconf -e virtual_mailbox_domains=mysql:/etc/postfix/g-virt.cf && \
    postconf -e virtual_transport="smtp:[localhost]:24"

COPY ./config_files/delivery_supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY   ./config_files/g-alias.cf ./config_files/g-virt.cf /etc/postfix/ 

EXPOSE 24

ENTRYPOINT ["/usr/bin/supervisord"]
