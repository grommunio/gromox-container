FROM opensuse/leap:15.3

ARG S6_OVERLAY_VERSION=3.1.2.1

RUN zypper install -y curl && \
      curl https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && \
      rpm --import gr.key && \
      zypper --non-interactive --quiet ar -C https://download.grommunio.com/community/openSUSE_Leap_15.3 grommunio && \
      zypper --gpg-auto-import-keys ref && \
      zypper -n refresh grommunio && \
      zypper in -y gromox grommunio-common mariadb-client nginx nginx-module-vts nginx-module-brotli nginx-module-zstd postfix \
		grommunio-antispam postfix-mysql grommunio-admin-api grommunio-admin-web grommunio-web vim grommunio-chat xz tar

# Setup S6
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

# Setup services in s6
RUN  /bin/sh -c 'mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d'
COPY build-assets/contents.d/ /etc/s6-overlay/s6-rc.d/user/contents.d
COPY build-assets/services/ /etc/s6-overlay/s6-rc.d

RUN postconf -e virtual_alias_maps=mysql:/etc/postfix/g-alias.cf && \
    postconf -e virtual_mailbox_domains=mysql:/etc/postfix/g-virt.cf && \
    postconf -e virtual_transport="smtp:[localhost]:24" 

COPY   ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 

COPY ./shell_files/* /scripts/

RUN chown root:gromox /etc/gromox && \ 
    chmod 775 /etc/gromox && \
    ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf 

ENTRYPOINT ["/init"]
