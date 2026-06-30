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

# Use persistent marker directory (survives restarts with volumes)
MARKER_DIR="/etc/gromox/.setup"
mkdir -p "${MARKER_DIR}"

# Allow forced reconfiguration via environment variable
if [ "${FORCE_RECONFIG}" = "true" ]; then
  rm -f "${MARKER_DIR}/db_done" "${MARKER_DIR}/entry_done"
fi

# Wait for database to be reachable
echo "Waiting for database ${MYSQL_HOST}..."
for i in $(seq 1 30); do
  mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -p"${MYSQL_PASS}" -e "SELECT 1" >/dev/null 2>&1 && break
  echo "  attempt $i/30 - retrying in 2s..."
  sleep 2
done

# Run DB initialization (once)
if [ ! -f "${MARKER_DIR}/db_done" ]; then
  /home/scripts/db.sh
  touch "${MARKER_DIR}/db_done"
fi

# Run entrypoint configuration (once)
if [ ! -f "${MARKER_DIR}/entry_done" ]; then
  /home/entrypoint.sh
  touch "${MARKER_DIR}/entry_done"
fi

# ── Port remapping ─────────────────────────────────────────────────
# Remap nginx to listen on high ports (>1024) so no privileges needed.
# The actual listen directives are in the included files under /usr/share/.

# Grommunio web: 80 -> 8080, 443 -> 8443
# Handle both "listen 80" and "listen [::]:80" formats
for f in /usr/share/grommunio-common/nginx.conf /etc/nginx/nginx.conf; do
  [ -f "$f" ] || continue
  sed -i 's/\blisten\s\+80\b/listen 8080/g; s/\blisten\s\+\[::]\:80\b/listen [::]:8080/g' "$f"
  sed -i 's/\blisten\s\+443\b/listen 8443/g; s/\blisten\s\+\[::]\:443\b/listen [::]:8443/g' "$f"
done

# Admin HTTP: 8080 -> 9080 (avoid conflict with remapped web port)
sed -i 's/\blisten\s\+8080\b/listen 9080/g; s/\blisten\s\+\[::]\:8080\b/listen [::]:9080/g' \
  /usr/share/grommunio-admin-common/nginx.conf

# Admin HTTPS: 8443 -> 9443
sed -i 's/\blisten\s\+8443\b/listen 9443/g; s/\blisten\s\+\[::]\:8443\b/listen [::]:9443/g' \
  /usr/share/grommunio-admin-common/nginx-ssl.conf

# Remap postfix to listen on high ports
postconf -e "smtp_bind_address=" || true
if [ -f /etc/postfix/master.cf ]; then
  # smtp (25->2525), submission (587->2587), smtps (465->2465)
  sed -i 's/^smtp\(\s\+\)inet/2525\1inet/' /etc/postfix/master.cf
  sed -i 's/^submission\(\s\+\)inet/2587\1inet/' /etc/postfix/master.cf
  sed -i 's/^smtps\(\s\+\)inet/2465\1inet/' /etc/postfix/master.cf
fi

# Remap gromox imap/pop3 ports
if [ -f /etc/gromox/imap.cfg ]; then
  sed -i 's/^listen_ssl_port\s*=\s*993/listen_ssl_port=2993/' /etc/gromox/imap.cfg
  sed -i 's/^listen_port\s*=\s*143/listen_port=2143/' /etc/gromox/imap.cfg
fi
if [ -f /etc/gromox/pop3.cfg ]; then
  sed -i 's/^listen_ssl_port\s*=\s*995/listen_ssl_port=2995/' /etc/gromox/pop3.cfg
  sed -i 's/^listen_port\s*=\s*110/listen_port=2110/' /etc/gromox/pop3.cfg
fi

# ── Conditional services ──────────────────────────────────────────

# Enable grommunio-chat if configured (check for chat config file existence)
if [ -f "${CHAT_CONFIG}" ] && [ -f /etc/supervisor.d/grommunio-chat.conf ]; then
  sed -i 's/autostart=false/autostart=true/' /etc/supervisor.d/grommunio-chat.conf
fi

# Set up certbot renewal if Let's Encrypt is enabled
if [ "${SSL_INSTALL_TYPE}" = "2" ]; then
  # On an actual renewal, rebuild the concatenated bundle that nginx and the
  # gromox http/imap/pop3 daemons read (certbot only refreshes the files under
  # /etc/letsencrypt/live, not this bundle) and restart the TLS services.
  # $RENEWED_LINEAGE is set by certbot to the renewed cert's live directory.
  cat > /usr/local/bin/grommunio-cert-deploy <<'DEPLOY'
#!/bin/bash
[ -n "${RENEWED_LINEAGE}" ] || exit 0
cat "${RENEWED_LINEAGE}/cert.pem" "${RENEWED_LINEAGE}/fullchain.pem" > /etc/grommunio-common/ssl/server-bundle.pem
cp -f "${RENEWED_LINEAGE}/privkey.pem" /etc/grommunio-common/ssl/server.key
chown gromox:gromox /etc/grommunio-common/ssl/* 2>/dev/null || true
supervisorctl restart gromox-http gromox-imap gromox-pop3 2>/dev/null || true
DEPLOY
  chmod +x /usr/local/bin/grommunio-cert-deploy

  # Renew on the published HTTP port (host :80 -> container :8080). nginx owns
  # 8080, so free it only while a renewal actually runs: the pre/post hooks
  # fire only when at least one certificate is due.
  echo "0 */12 * * * root certbot renew --quiet --standalone --http-01-port 8080 --pre-hook 'supervisorctl stop nginx' --deploy-hook /usr/local/bin/grommunio-cert-deploy --post-hook 'supervisorctl start nginx'" > /etc/cron.d/certbot-renew
fi

exec /usr/local/bin/supervisord -n -c /etc/supervisord.conf
