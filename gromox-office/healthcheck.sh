#!/bin/bash
# Container health: unhealthy while any supervised program is not running.
status=$(supervisorctl status 2>/dev/null) || exit 1
echo "${status}" | grep -qE 'FATAL|BACKOFF|EXITED|STOPPED|UNKNOWN' && { echo "${status}" | grep -E 'FATAL|BACKOFF|EXITED|STOPPED|UNKNOWN'; exit 1; }
exit 0
