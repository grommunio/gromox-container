#!/bin/bash
# Re-install the TLS certificate when the files behind SSL_BUNDLE / SSL_KEY
# change (SSL_INSTALL_TYPE=3; in Kubernetes the kubelet refreshes a mounted
# TLS secret in place when cert-manager or the operator rotates it) and
# reload/restart the services that hold the certificate in memory.
# Runs as a supervisor program (autostart only when CERT_WATCH=true).
#
#   CERT_WATCH_INTERVAL   seconds between checks (default 60)
#   CERT_WATCH_RELOAD     space separated: "nginx" and/or "postfix" (reload, no downtime)
#   CERT_WATCH_RESTART    space separated supervisor programs to restart
. /home/common/helpers
. /home/common/ssl_setup

interval="${CERT_WATCH_INTERVAL:-60}"
fingerprint() { cat "${SSL_BUNDLE}" "${SSL_KEY}" "${SSL_CA:-/dev/null}" 2>/dev/null | sha256sum | cut -d' ' -f1; }
installed() { cat "${SSL_BUNDLE_T}" "${SSL_KEY_T}" 2>/dev/null | sha256sum | cut -d' ' -f1; }

if [ "${SSL_INSTALL_TYPE:-0}" != "3" ] || [ -z "${SSL_BUNDLE:-}" ] || [ -z "${SSL_KEY:-}" ]; then
  echo "cert-watch: SSL_INSTALL_TYPE is not 3, nothing to watch; sleeping"
  exec sleep infinity
fi

last=$(fingerprint)
echo "cert-watch: watching ${SSL_BUNDLE} and ${SSL_KEY} every ${interval}s"
while sleep "${interval}"; do
  now=$(fingerprint)
  [ "${now}" = "${last}" ] && continue
  if ! openssl x509 -in "${SSL_BUNDLE}" -noout >/dev/null 2>&1 || ! openssl pkey -in "${SSL_KEY}" -noout >/dev/null 2>&1; then
    echo "cert-watch: new certificate files are not (yet) valid, retrying"
    continue
  fi
  echo "cert-watch: certificate changed, installing"
  if ! owncert; then
    echo "cert-watch: installing the certificate failed"
    continue
  fi
  chmod 0644 "${SSL_BUNDLE_T}"
  [ -n "${CERT_OWNER:-}" ] && chown "${CERT_OWNER}" "${SSL_BUNDLE_T}" "${SSL_KEY_T}" 2>/dev/null
  last="${now}"
  for svc in ${CERT_WATCH_RELOAD:-}; do
    case "${svc}" in
      nginx)   nginx -s reload && echo "cert-watch: nginx reloaded" ;;
      postfix) postfix reload >/dev/null 2>&1 && echo "cert-watch: postfix reloaded" ;;
    esac
  done
  for prog in ${CERT_WATCH_RESTART:-}; do
    if /usr/local/bin/supervisorctl status "${prog}" 2>/dev/null | grep -q RUNNING; then
      /usr/local/bin/supervisorctl restart "${prog}" >/dev/null && echo "cert-watch: ${prog} restarted"
    fi
  done
done
