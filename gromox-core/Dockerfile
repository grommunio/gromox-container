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

# Package channel: "community" (public repository) or "supported" (subscription
# repository). Supported builds need the subscription credentials as a BuildKit
# secret in zypper credentials format (username=... / password=...):
#   docker build --build-arg GROMMUNIO_CHANNEL=supported \
#     --secret id=grommunio_repo,src=/path/to/credentials ...
# The secret is mounted only while zypper runs and is not part of any layer.
ARG GROMMUNIO_CHANNEL=community
LABEL com.grommunio.channel="${GROMMUNIO_CHANNEL}"
ENV GROMMUNIO_CHANNEL="${GROMMUNIO_CHANNEL}"

RUN	--mount=type=secret,id=grommunio_repo,target=/etc/zypp/credentials.d/grommunio \
	curl -fsSL https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && \
	  rpm --import gr.key && rm -f gr.key && \
	  case "${GROMMUNIO_CHANNEL}" in \
	    community) url="https://download.grommunio.com/community/${GROMMUNIO_REPO}" ;; \
	    supported) test -s /etc/zypp/credentials.d/grommunio || \
	                 { echo "GROMMUNIO_CHANNEL=supported needs --secret id=grommunio_repo,src=<credentials file>" >&2; exit 1; }; \
	               url="https://download.grommunio.com/supported/${GROMMUNIO_REPO}?credentials=grommunio" ;; \
	    *) echo "GROMMUNIO_CHANNEL must be community or supported" >&2; exit 1 ;; \
	  esac && \
	  zypper --non-interactive --quiet ar -C "${url}" grommunio && \
	  zypper --non-interactive ref && \
	  zypper -n refresh grommunio

# Install grommunio packages (retry up to 3 times for transient download errors)
RUN --mount=type=secret,id=grommunio_repo,target=/etc/zypp/credentials.d/grommunio \
    zypper --non-interactive install -y vim mysql nginx \
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
RUN --mount=type=secret,id=grommunio_repo,target=/etc/zypp/credentials.d/grommunio \
    zypper -n install -y python313-certbot python313-certbot-nginx glibc-gconv-modules-extra

# Install supervisord (Python 3.13 is the system default on openSUSE Leap 16)
RUN --mount=type=secret,id=grommunio_repo,target=/etc/zypp/credentials.d/grommunio \
    zypper -n install -y python313-pip && \
    pip3.13 install --no-cache-dir supervisor && \
    zypper clean -a

COPY common /home/common
# Snapshot of the package-provided content of every path that is a volume at
# runtime; restored into empty volumes by the entrypoint (Kubernetes PVCs start
# out empty, Docker named volumes are populated from the image).
RUN /home/common/seed-build.sh \
      /etc/gromox /etc/grommunio-admin-api /etc/grommunio-admin-common/license \
      /etc/grommunio-chat /var/lib/grommunio-chat \
      /var/lib/grommunio-admin-api /var/lib/grommunio-antispam /var/lib/grommunio-dav \
      /var/lib/grommunio-web /var/lib/redis /var/lib/gromox /var/spool/postfix

COPY gromox-core/scripts /home/scripts
COPY gromox-core/config /home/config
COPY gromox-core/entrypoint.sh gromox-core/configure.sh gromox-core/docker-entrypoint.sh /home/
RUN chmod +x /home/scripts/db.sh /home/entrypoint.sh /home/configure.sh /home/docker-entrypoint.sh && \
    ln -s /home/common/healthcheck.sh /home/healthcheck.sh

COPY gromox-core/supervisord.conf /etc/supervisord.conf
COPY gromox-core/supervisor.d /etc/supervisor.d
COPY common/supervisor-cert-watch.conf /etc/supervisor.d/cert-watch.conf

# Programs checked by "healthcheck.sh --essential" (Kubernetes probes)
ENV HEALTHCHECK_ESSENTIAL="nginx postfix gromox-http gromox-midb gromox-zcore gromox-delivery gromox-delivery-queue gromox-imap gromox-pop3 php-fpm grommunio-admin-api grommunio-antispam redis saslauthd"

ENTRYPOINT ["/home/docker-entrypoint.sh"]
