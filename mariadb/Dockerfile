# MariaDB for the grommunio Helm chart: the official MariaDB image with the
# current Ubuntu security updates, rebuilt daily together with the gromox
# images. gosu (a Go binary that lags behind Go security releases) is replaced
# by setpriv from util-linux; the entrypoint uses it only when started as root,
# the Helm chart runs MariaDB as uid 999.
#
#   tools/publish-images.sh -t 11.8 mariadb
ARG MARIADB_IMAGE=docker.io/library/mariadb:11.8
FROM ${MARIADB_IMAGE}

RUN set -eux; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends upgrade; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/* /var/log/apt /var/log/dpkg.log; \
	rm -f /usr/local/bin/gosu /usr/sbin/gosu

COPY --chmod=0755 mariadb/gosu /usr/local/bin/gosu
RUN set -eux; \
	[ "$(gosu mysql id -u)" = "$(id -u mysql)" ]; \
	[ "$(gosu mysql:mysql id -g)" = "$(id -g mysql)" ]; \
	[ "$(gosu 999 id -u)" = 999 ]; \
	[ "$(setpriv --reuid=999 --regid=999 --clear-groups gosu mysql id -u)" = 999 ]
