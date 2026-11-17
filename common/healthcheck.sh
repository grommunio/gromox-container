#!/bin/bash
# Container health, shared by gromox-core, gromox-archive and gromox-office.
#
#   healthcheck.sh              unhealthy while ANY supervised program that is
#                               meant to run (autostart=true) is not RUNNING
#   healthcheck.sh --essential  unhealthy only while one of the programs in
#                               HEALTHCHECK_ESSENTIAL (space separated; the
#                               image sets a default) is not RUNNING. Used as
#                               Kubernetes probe so that an optional program
#                               (chat, indexer, cron) cannot restart the pod.
status=$(/usr/local/bin/supervisorctl status 2>/dev/null); rc=$?
# 0 = all running, 3 = some program not running (inspected below), 4 = cannot talk to supervisord
[ $rc -eq 0 ] || [ $rc -eq 3 ] || { echo "supervisord not reachable (rc=$rc)"; exit 1; }

if [ "${1:-}" = "--essential" ] && [ -n "${HEALTHCHECK_ESSENTIAL:-}" ]; then
  bad=""
  for prog in ${HEALTHCHECK_ESSENTIAL}; do
    # programs disabled by configuration (autostart=false) are not essential
    grep -qE '^autostart=false' "/etc/supervisor.d/${prog}.conf" 2>/dev/null && continue
    line=$(echo "${status}" | awk -v p="${prog}" '$1==p')
    [ -z "${line}" ] && continue
    echo "${line}" | grep -qE 'RUNNING' || bad="${bad}${line}"$'\n'
  done
else
  disabled=$(grep -lE '^autostart=false' /etc/supervisor.d/*.conf 2>/dev/null | xargs -r -n1 basename | sed 's/\.conf$//' | paste -sd'|')
  bad=$(echo "${status}" | grep -vE "^(${disabled:-__none__})[[:space:]]" | grep -E 'FATAL|BACKOFF|EXITED|STOPPED|UNKNOWN')
fi
if [ -n "${bad}" ]; then
  echo "${bad}"
  exit 1
fi
exit 0
