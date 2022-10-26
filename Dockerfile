FROM opensuse/leap:15.3

RUN zypper install -y curl && \
      curl https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && \
      rpm --import gr.key && \
      zypper --non-interactive --quiet ar -C https://download.grommunio.com/community/openSUSE_Leap_15.3 grommunio && \
      zypper --gpg-auto-import-keys ref && \
      zypper -n refresh grommunio && \
      zypper in -y gromox grommunio-common mariadb-client nginx nginx-module-vts nginx-module-brotli nginx-module-zstd postfix postfix-mysql grommunio-admin-api grommunio-admin-web grommunio-web vim grommunio-chat

RUN postconf -e virtual_alias_maps=mysql:/etc/postfix/g-alias.cf && \
    postconf -e virtual_mailbox_domains=mysql:/etc/postfix/g-virt.cf && \
    postconf -e virtual_transport="smtp:[localhost]:24" 

#COPY  ./config_files/*.cfg  /etc/gromox/

COPY   ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 

COPY ./shell_files/* /scripts/

RUN chown root:gromox /etc/gromox && \ 
    chmod 775 /etc/gromox && \
    ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf 

CMD ["tail", "-f", "/dev/null"]

