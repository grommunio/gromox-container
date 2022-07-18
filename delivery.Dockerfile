FROM olam1k0/grommunio:latest

RUN DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y postfix postfix-mysql

RUN postconf -e virtual_alias_maps=mysql:/etc/postfix/g-alias.cf && \
    postconf -e virtual_mailbox_domains=mysql:/etc/postfix/g-virt.cf && \
    postconf -e virtual_transport="smtp:[localhost]:24" && \
    touch /etc/postfix/virtual && \
    touch /etc/postfix/access && \
    postmap hash:/etc/postfix/virtual && \
    postmap hash:/etc/postfix/access

RUN mkdir -p /etc/apt/keyrings && \
      curl -s https://rspamd.com/apt-stable/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/rspamd.gpg > /dev/null && \
      echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rspamd.gpg] http://rspamd.com/apt-stable/ bullseye main" |  tee /etc/apt/sources.list.d/rspamd.list && \
      echo "deb-src [arch=amd64 signed-by=/etc/apt/keyrings/rspamd.gpg] http://rspamd.com/apt-stable/ bullseye main"  |  tee -a /etc/apt/sources.list.d/rspamd.list && \
      apt-get update && \
      apt-get --no-install-recommends install -y rspamd

COPY ./config_files/delivery_supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY ./shell_files/db.sh ./shell_files/delivery.sh /scripts/

COPY ./config_files/rspamd/* /etc/rspamd/local.d/

EXPOSE 24 25 5555 11333 11334

ENTRYPOINT ["/usr/bin/supervisord"]

