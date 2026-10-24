#!/bin/bash
# Container health: unhealthy while a supervised program that is meant to run
# is not running. Programs disabled by configuration (autostart=false, e.g.
# chat or office when the feature is off) are ignored.
status=$(supervisorctl status 2>/dev/null); rc=$?
# 0 = all running, 3 = some program not running (inspected below), 4 = cannot talk to supervisord
[ $rc -eq 0 ] || [ $rc -eq 3 ] || exit 1
disabled=$(grep -lE '^autostart=false' /etc/supervisor.d/*.conf 2>/dev/null | xargs -r -n1 basename | sed 's/\.conf$//' | paste -sd'|')
bad=$(echo "${status}" | grep -vE "^(${disabled:-__none__})[[:space:]]" | grep -E 'FATAL|BACKOFF|EXITED|STOPPED|UNKNOWN')
if [ -n "${bad}" ]; then
  echo "${bad}"
  exit 1
fi
exit 0
