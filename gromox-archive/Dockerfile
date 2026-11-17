# Container image with openSUSE Leap + supervisord
#
# Description:
#
# This image runs grommunio-archive services using supervisord as PID 1,
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
        util-linux-systemd \
        nano       \
        lsof

# Default timezone — can be overridden at runtime via the TIMEZONE env var in var.env
RUN ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime && \
    echo "Europe/Vienna" > /etc/timezone

# Package channel: "community" (public repository) or "supported" (subscription
# repository). Supported builds need the subscription credentials as a BuildKit
# secret in zypper credentials format (username=... / password=...):
#   docker build --build-arg GROMMUNIO_CHANNEL=supported \
#     --secret id=grommunio_repo,src=/path/to/credentials ...
# zypper needs a writable credentials file, so the secret is copied into a
# tmpfs for each RUN that uses the repository; it is not part of any layer.
ARG GROMMUNIO_CHANNEL=community
LABEL com.grommunio.channel="${GROMMUNIO_CHANNEL}"
ENV GROMMUNIO_CHANNEL="${GROMMUNIO_CHANNEL}"

RUN	--mount=type=secret,id=grommunio_repo --mount=type=tmpfs,target=/etc/zypp/credentials.d \
	{ [ ! -s /run/secrets/grommunio_repo ] || install -m 0600 /run/secrets/grommunio_repo /etc/zypp/credentials.d/grommunio; } && \
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

# Install grommunio packages (retry up to 3 times for transient download errors).
# util-linux-systemd provides /usr/bin/logger, used by the packaged indexer scripts.
# The archive web UI needs more PHP extensions than the package pulls in
# (iconv/ctype for MIME decoding, mbstring, zip, ldap, intl, ...).
RUN --mount=type=secret,id=grommunio_repo --mount=type=tmpfs,target=/etc/zypp/credentials.d \
    { [ ! -s /run/secrets/grommunio_repo ] || install -m 0600 /run/secrets/grommunio_repo /etc/zypp/credentials.d/grommunio; } && \
    zypper --non-interactive install -y vim mysql \
         php8-mysql php8-cli php8-openssl php-fpm php-gd grommunio-archive sphinx nginx jq grommunio-common \
         php8-iconv php8-ctype php8-mbstring php8-zip php8-zlib php8-curl php8-ldap php8-intl php8-bcmath php8-dom php8-posix php8-exif php8-fileinfo \
       || { echo "Retry 1..."; zypper clean -a; sleep 5; \
            zypper --non-interactive install -y vim mysql \
              php8-mysql php8-cli php8-openssl php-fpm php-gd grommunio-archive sphinx nginx jq grommunio-common \
              php8-iconv php8-ctype php8-mbstring php8-zip php8-zlib php8-curl php8-ldap php8-intl php8-bcmath php8-dom php8-posix php8-exif php8-fileinfo; } \
       || { echo "Retry 2..."; zypper clean -a; sleep 10; \
            zypper --non-interactive install -y vim mysql \
              php8-mysql php8-cli php8-openssl php-fpm php-gd grommunio-archive sphinx nginx jq grommunio-common \
              php8-iconv php8-ctype php8-mbstring php8-zip php8-zlib php8-curl php8-ldap php8-intl php8-bcmath php8-dom php8-posix php8-exif php8-fileinfo; }

# Install supervisord (Python 3.13 is the system default on openSUSE Leap 16)
RUN --mount=type=secret,id=grommunio_repo --mount=type=tmpfs,target=/etc/zypp/credentials.d \
    { [ ! -s /run/secrets/grommunio_repo ] || install -m 0600 /run/secrets/grommunio_repo /etc/zypp/credentials.d/grommunio; } && \
    zypper -n install -y python313-pip && \
    pip3.13 install --no-cache-dir supervisor && \
    zypper clean -a

COPY common /home/common
# Seed for empty volumes (see gromox-core/Dockerfile)
RUN /home/common/seed-build.sh /var/lib/grommunio-archive

COPY gromox-archive/config /home/config
COPY gromox-archive/entrypoint.sh gromox-archive/configure.sh gromox-archive/docker-entrypoint.sh /home/
RUN chmod +x /home/entrypoint.sh /home/configure.sh /home/docker-entrypoint.sh && \
    ln -s /home/common/healthcheck.sh /home/healthcheck.sh

COPY gromox-archive/supervisord.conf /etc/supervisord.conf
COPY gromox-archive/supervisor.d /etc/supervisor.d
COPY common/supervisor-cert-watch.conf /etc/supervisor.d/cert-watch.conf

ENV HEALTHCHECK_ESSENTIAL="grommunio-archive grommunio-archive-smtp searchd nginx php-fpm"

ENTRYPOINT ["/home/docker-entrypoint.sh"]
