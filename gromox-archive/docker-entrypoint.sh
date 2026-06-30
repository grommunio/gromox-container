#!/bin/bash
set -e

# Source environment variables
if [ -f /home/vars/var.env ]; then
  set -a
  . /home/vars/var.env
  set +a
fi

# Apply timezone from var.env (TIMEZONE); falls back to the image default if unset/invalid
if [ -n "${TIMEZONE}" ] && [ -f "/usr/share/zoneinfo/${TIMEZONE}" ]; then
  ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
  echo "${TIMEZONE}" > /etc/timezone
fi

# Use persistent marker directory (on shared /data volume)
MARKER_DIR="/data/.setup-archive"
mkdir -p "${MARKER_DIR}"

# Allow forced reconfiguration via environment variable
if [ "${FORCE_RECONFIG}" = "true" ]; then
  rm -f "${MARKER_DIR}/entry_done"
fi

# Run entrypoint configuration (once)
if [ ! -f "${MARKER_DIR}/entry_done" ]; then
  /home/entrypoint.sh
  touch "${MARKER_DIR}/entry_done"
fi

# ── SSL certificate config ────────────────────────────────────────
# Create nginx SSL config pointing to shared cert volume
mkdir -p /etc/grommunio-common/nginx
cat > /etc/grommunio-common/nginx/ssl_certificate.conf <<'SSLEOF'
ssl_certificate /etc/grommunio-common/ssl/server-bundle.pem;
ssl_certificate_key /etc/grommunio-common/ssl/server.key;
SSLEOF

# ── Port remapping ─────────────────────────────────────────────────
# Remap nginx: 80 -> 8080, 443 -> 8443
for f in /usr/share/grommunio-common/nginx.conf /etc/nginx/nginx.conf; do
  [ -f "$f" ] || continue
  sed -i 's/\blisten\s\+80\b/listen 8080/g; s/\blisten\s\+\[::]\:80\b/listen [::]:8080/g' "$f"
  sed -i 's/\blisten\s\+443\b/listen 8443/g; s/\blisten\s\+\[::]\:443\b/listen [::]:8443/g' "$f"
done

exec /usr/local/bin/supervisord -n -c /etc/supervisord.conf
