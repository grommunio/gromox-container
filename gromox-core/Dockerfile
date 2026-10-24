# Container image with openSUSE Leap + supervisord
#
# Description:
#
# This image runs grommunio-core services using supervisord as PID 1,
# eliminating the need for systemd, privileged mode, and sysbox runtime.

FROM opensuse/leap:16.0

ARG GROMMUNIO_REPO=openSUSE_Leap_16.0

RUN zypper -n install -y \
        iproute2    \
        curl    \
        patterns-base-base \
        procps  \
        sudo       \
        cronie     \
        bind-utils \
        timezone   \
        lsof       \
        nano

# Default timezone — can be overridden at runtime via the TIMEZONE env var in var.env
RUN ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime && \
    echo "Europe/Vienna" > /etc/timezone

RUN	curl -fsSL https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && \
	  rpm --import gr.key && rm -f gr.key && \
	  zypper --non-interactive --quiet ar -C https://download.grommunio.com/community/${GROMMUNIO_REPO} grommunio && \
	  zypper --non-interactive ref && \
	  zypper -n refresh grommunio

# Install grommunio packages (retry up to 3 times for transient download errors)
RUN    zypper --non-interactive install -y vim mysql nginx \
         gromox grommunio-admin-api grommunio-admin-web grommunio-antispam \
         grommunio-common grommunio-web grommunio-index grommunio-sync grommunio-dav postfix postfix-mysql \
         grommunio-chat grommunio-keycloak grommunio-auth cyrus-sasl-saslauthd cyrus-sasl-plain jq redis \
       || { echo "Retry 1..."; zypper clean -a; sleep 5; \
            zypper --non-interactive install -y vim mysql nginx \
              gromox grommunio-admin-api grommunio-admin-web grommunio-antispam \
              grommunio-common grommunio-web grommunio-index grommunio-sync grommunio-dav postfix postfix-mysql \
              grommunio-chat grommunio-keycloak grommunio-auth cyrus-sasl-saslauthd cyrus-sasl-plain jq redis; } \
       || { echo "Retry 2..."; zypper clean -a; sleep 10; \
            zypper --non-interactive install -y vim mysql nginx \
              gromox grommunio-admin-api grommunio-admin-web grommunio-antispam \
              grommunio-common grommunio-web grommunio-index grommunio-sync grommunio-dav postfix postfix-mysql \
              grommunio-chat grommunio-keycloak grommunio-auth cyrus-sasl-saslauthd cyrus-sasl-plain jq redis; }

# The admin API's JWT signing key must not be baked into the image (it would be
# shared by every deployment using this image); configure.sh generates it on the
# persistent volume at first start.
RUN rm -f /etc/grommunio-admin-api/jwt-privkey.pem /etc/grommunio-admin-api/jwt-pubkey.pem

# Install Certbot from openSUSE 16 packages + iconv modules (iso-2022-jp etc.)
RUN    zypper -n install -y python313-certbot python313-certbot-nginx glibc-gconv-modules-extra

# Install supervisord (Python 3.13 is the system default on openSUSE Leap 16)
RUN zypper -n install -y python313-pip && \
    pip3.13 install --no-cache-dir supervisor && \
    zypper clean -a

COPY gromox-core/scripts /home/scripts
COPY gromox-core/common /home/common
COPY gromox-core/config /home/config
COPY gromox-core/entrypoint.sh gromox-core/configure.sh gromox-core/docker-entrypoint.sh gromox-core/healthcheck.sh /home/
RUN chmod +x /home/scripts/db.sh /home/entrypoint.sh /home/configure.sh /home/docker-entrypoint.sh /home/healthcheck.sh

COPY gromox-core/supervisord.conf /etc/supervisord.conf
COPY gromox-core/supervisor.d /etc/supervisor.d

ENTRYPOINT ["/home/docker-entrypoint.sh"]
