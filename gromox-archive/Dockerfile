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

RUN	curl -fsSL https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && \
	  rpm --import gr.key && rm -f gr.key && \
	  zypper --non-interactive --quiet ar -C https://download.grommunio.com/community/${GROMMUNIO_REPO} grommunio && \
	  zypper --non-interactive ref && \
	  zypper -n refresh grommunio

# Install grommunio packages (retry up to 3 times for transient download errors).
# util-linux-systemd provides /usr/bin/logger, used by the packaged indexer scripts.
# The archive web UI needs more PHP extensions than the package pulls in
# (iconv/ctype for MIME decoding, mbstring, zip, ldap, intl, ...).
RUN    zypper --non-interactive install -y vim mysql \
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
RUN zypper -n install -y python313-pip && \
    pip3.13 install --no-cache-dir supervisor && \
    zypper clean -a

COPY gromox-archive/common /home/common
COPY gromox-archive/config /home/config
COPY gromox-archive/entrypoint.sh gromox-archive/configure.sh gromox-archive/docker-entrypoint.sh gromox-archive/healthcheck.sh /home/
RUN chmod +x /home/entrypoint.sh /home/configure.sh /home/docker-entrypoint.sh /home/healthcheck.sh

COPY gromox-archive/supervisord.conf /etc/supervisord.conf
COPY gromox-archive/supervisor.d /etc/supervisor.d

ENTRYPOINT ["/home/docker-entrypoint.sh"]
