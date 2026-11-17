# Container image with openSUSE Leap + supervisord
#
# Description:
#
# This image runs grommunio-office/files services using supervisord as PID 1,
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
    zypper --non-interactive install -y vim nginx \
         mysql grommunio-common jq php-fpm redis grommunio-files rabbitmq-server grommunio-office \
       || { echo "Retry 1..."; zypper clean -a; sleep 5; \
            zypper --non-interactive install -y vim nginx \
              mysql grommunio-common jq php-fpm redis grommunio-files rabbitmq-server grommunio-office; } \
       || { echo "Retry 2..."; zypper clean -a; sleep 10; \
            zypper --non-interactive install -y vim nginx \
              mysql grommunio-common jq php-fpm redis grommunio-files rabbitmq-server grommunio-office; }

# Install supervisord (Python 3.13 is the system default on openSUSE Leap 16)
RUN --mount=type=secret,id=grommunio_repo,target=/etc/zypp/credentials.d/grommunio \
    zypper -n install -y python313-pip && \
    pip3.13 install --no-cache-dir supervisor && \
    zypper clean -a

# Generate the document server's font and theme data at build time; at
# container start this takes minutes. The entrypoint still generates it when
# the stamp file is missing.
RUN set -e; export LD_LIBRARY_PATH=/usr/libexec/grommunio-office/server/FileConverter/bin; \
    /usr/libexec/grommunio-office/server/tools/allfontsgen \
      --input="/usr/share/fonts" \
      --allfonts-web="/usr/libexec/grommunio-office/sdkjs/common/AllFonts.js" \
      --allfonts="/usr/libexec/grommunio-office/server/FileConverter/bin/AllFonts.js" \
      --images="/usr/libexec/grommunio-office/sdkjs/common/Images" \
      --selection="/usr/libexec/grommunio-office/server/FileConverter/bin/font_selection.bin" \
      --output-web="/usr/libexec/grommunio-office/fonts" \
      --use-system=true; \
    for variant in "" "--postfix=ios --params=280,224" "--postfix=android --params=280,224"; do \
      /usr/libexec/grommunio-office/server/tools/allthemesgen \
        --converter-dir="/usr/libexec/grommunio-office/server/FileConverter/bin" \
        --src="/usr/libexec/grommunio-office/sdkjs/slide/themes" \
        --output="/usr/libexec/grommunio-office/sdkjs/common/Images" ${variant}; \
    done; \
    /usr/libexec/grommunio-office/server/FileConverter/bin/x2t -create-js-cache || true; \
    touch /usr/libexec/grommunio-office/.fonts-generated

COPY common /home/common
# Seed for empty volumes (see gromox-core/Dockerfile)
RUN /home/common/seed-build.sh /var/lib/grommunio-files /var/lib/grommunio-office /var/lib/rabbitmq /var/lib/redis

COPY gromox-office/config /home/config
COPY gromox-office/entrypoint.sh gromox-office/configure.sh gromox-office/docker-entrypoint.sh /home/
RUN chmod +x /home/entrypoint.sh /home/configure.sh /home/docker-entrypoint.sh && \
    ln -s /home/common/healthcheck.sh /home/healthcheck.sh

COPY gromox-office/supervisord.conf /etc/supervisord.conf
COPY gromox-office/supervisor.d /etc/supervisor.d
COPY common/supervisor-cert-watch.conf /etc/supervisor.d/cert-watch.conf

ENV HEALTHCHECK_ESSENTIAL="nginx php-fpm redis ds-docservice ds-converter rabbitmq"

ENTRYPOINT ["/home/docker-entrypoint.sh"]
