#!/bin/bash
# One-time core database initialisation (gromox schema).
# gromox-dbop reads the credentials from /etc/gromox/mysql_adaptor.cfg, which
# configure.sh rewrites on every start; write it here as well because this
# script runs before configure.sh on the very first start.

. /home/common/helpers

CFG=/etc/gromox/mysql_adaptor.cfg
touch "${CFG}"
setconf "${CFG}" mysql_username "${MYSQL_USER}"
setconf "${CFG}" mysql_password "${MYSQL_PASS}"
setconf "${CFG}" mysql_dbname "${MYSQL_DB}"
setconf "${CFG}" mysql_host "${MYSQL_HOST}"
chmod 0640 "${CFG}"
chgrp gromoxcf "${CFG}" 2>/dev/null || true

TABLES=$(mariadb -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -p"${MYSQL_PASS}" -N -s -e \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema = '${MYSQL_DB}';" 2>>"${LOGFILE}")
TABLES="${TABLES:-0}"
echo "Core database ${MYSQL_DB} has ${TABLES} tables" >>"${LOGFILE}"

if [ "${TABLES}" = "0" ]; then
	echo 'Gromox DB is not populated, populating it...' >>"${LOGFILE}"
	gromox-dbop -C >>"${LOGFILE}" 2>&1
elif [ "${CLEAR_DBS}" = "true" ]; then
	# Explicit opt-in only: drops ALL mail metadata.
	echo "CLEAR_DBS=true: dropping and recreating ${MYSQL_DB}" | tee -a "${LOGFILE}"
	if [ -z "${MYSQL_ROOT_PASS}" ]; then
		echo "CLEAR_DBS=true requires MYSQL_ROOT_PASS; skipping" | tee -a "${LOGFILE}"
	else
		MYSQL_PWD="${MYSQL_ROOT_PASS}" mariadb -h "${MYSQL_HOST}" -u root >>"${LOGFILE}" 2>&1 <<EOF
DROP DATABASE IF EXISTS \`${MYSQL_DB}\`;
CREATE DATABASE \`${MYSQL_DB}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASS}';
GRANT ALL ON \`${MYSQL_DB}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
		gromox-dbop -C >>"${LOGFILE}" 2>&1
	fi
else
	echo 'Gromox DB is populated, keeping it (schema upgrades are applied by gromox-http via schema_upgrade=host)' >>"${LOGFILE}"
fi
