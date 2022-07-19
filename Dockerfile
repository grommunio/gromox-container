FROM opensuse/leap:15.3

RUN zypper install -y curl && \
      curl https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && \
      rpm --import gr.key && \
      zypper --non-interactive --quiet ar -C https://download.grommunio.com/community/openSUSE_Leap_15.3 grommunio && \
      zypper --gpg-auto-import-keys ref && \
      zypper -n refresh grommunio && \
      zypper in -y gromox grommunio-common mariadb-client nginx nginx-module-vts postfix postfix-mysql

RUN postconf -e virtual_alias_maps=mysql:/etc/postfix/g-alias.cf && \
    postconf -e virtual_mailbox_domains=mysql:/etc/postfix/g-virt.cf && \
    postconf -e virtual_transport="smtp:[localhost]:24" 

COPY  ./config_files/*.cfg  /etc/gromox/

COPY   ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 

COPY   ./config_files/gromox.conf /usr/share/grommunio-common/nginx/upstreams.d/gromox.conf

COPY   ./config_files/admin_api_nginx.conf /usr/share/grommunio-common/nginx/locations.d/admin-api.conf

COPY ./shell_files/* /scripts/
#EXPOSE 5000

# Set up PHP FPM service
#RUN mv /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.bak && \
#       service php7.4-fpm start

CMD ["tail", "-f", "/dev/null"]
