#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2021 grommunio GmbH
# Interactive grommunio setup

DATADIR="${0%/*}"
if [ "${DATADIR}" = "$0" ]; then
	DATADIR="/home"
else
	DATADIR="$(readlink -f "$0")"
	DATADIR="${DATADIR%/*}"
	DATADIR="$(readlink -f "${DATADIR}")"
fi
if ! test -e "$LOGFILE"; then
	true >"$LOGFILE"
	chmod 0600 "$LOGFILE"
fi
# shellcheck source=common/helpers
. "${DATADIR}/common/helpers"
TMPF=$(mktemp /tmp/grommunio-setup.XXXXXXXX)

memory_check()
{

  local HAVE=$(perl -lne 'print $1 if m{^MemTotal:\s*(\d+)}i' </proc/meminfo)
  # Install the threshold a little lower than what we ask, to account for
  # FW/OS (Vbox with 4194304 KB ends up with MemTotal of about 4020752 KB)
  local THRES=4000000
  local ASK=4096000
  if [ -z "${HAVE}" ] || [ "${HAVE}" -ge "${THRES}" ]; then
    return 0
  fi
  memory_notice $((HAVE/1024)) $((ASK/1024))

}

memory_check

# Set repository credentials directly
# shellcheck source=common/repo
#INSTALLVALUE="core, chat, files, office, archive"
INSTALLVALUE="core, chat"

X500="i$(printf "%llx" "$(date +%s)")"
#Choose Install type, 0 for self signed, 2 to provide certificate and 3 for letsencrypt.
SSL_INSTALL_TYPE=0

SSL_COUNTRY="XX"
SSL_STATE="XX"
SSL_LOCALITY="X"
SSL_ORG="grommunio Appliance"
SSL_OU="IT"
SSL_EMAIL="admin@${DOMAIN}"
SSL_DAYS=30
SSL_PASS=grommunio

. "/home/common/ssl_setup"
mkdir /etc/grommunio-common/ssl
RETCMD=1
if [ "${SSL_INSTALL_TYPE}" = "0" ]; then
  clear
  if ! selfcert; then
  touch ssle
  fi
elif [ "${SSL_INSTALL_TYPE}" = "2" ]; then
  choose_ssl_selfprovided
  fullca
  SSL_BUNDLE=/home/ssl/grommox.pem
  SSL_KEY=/home/ssl/grommox.pem
  while [ ${RETCMD} -ne 0 ]; do
    owncert
    RETCMD=$?
  done
elif [ "${SSL_INSTALL_TYPE}" = "3" ]; then
  choose_ssl_letsencrypt
  #this should containe the domain to signed by certbot
  SSL_DOMAINS=$FQDN

  #This should contain the email
  SSL_EMAIL=email@$FQDN
  letsencrypt
fi

[ -e "/etc/grommunio-common/ssl" ] || mkdir -p "/etc/grommunio-common/ssl"

# Configure config.json of admin-web
cat > /etc/grommunio-admin-common/nginx.d/web-config.conf <<EOF
location /config.json {
  alias /etc/grommunio-admin-common/config.json;
}
EOF

# Generate AAPI DB access
generate_admin_db_conf "/etc/grommunio-admin-api/conf.d/database.yaml"

echo "{ \"mailWebAddress\": \"https://${FQDN}/web\", \"rspamdWebAddress\": \"https://${FQDN}:8443/antispam/\" }" | jq > /tmp/config.json

if [[ $INSTALLVALUE == *"chat"* ]] ; then
  systemctl stop grommunio-chat

    echo "drop database if exists ${CHAT_MYSQL_DB}; \
          create database ${CHAT_MYSQL_DB};" | mysql -h"${CHAT_MYSQL_HOST}" -u"${CHAT_MYSQL_USER}" -p"${CHAT_MYSQL_PASS}" "${CHAT_MYSQL_DB}" >/dev/null 2>&1

  CHAT_DB_CON="${CHAT_MYSQL_USER}:${CHAT_MYSQL_PASS}@tcp\(${CHAT_MYSQL_HOST}:3306\)\/${CHAT_MYSQL_DB}?charset=utf8mb4,utf8\&readTimeout=30s\&writeTimeout=30s"
  sed -i 's#^.*"DataSource":.*#        "DataSource": "'${CHAT_DB_CON}'",#g' "${CHAT_CONFIG}"
  sed -i 's#^.*"DriverName": "postgres".*#        "DriverName": "mysql",#g' "${CHAT_CONFIG}"
  sed -i 's#^.*"EnableAPIUserDeletion":.*#        "EnableAPIUserDeletion": true,#g' "${CHAT_CONFIG}"
  sed -i 's|"SiteURL": "",|"SiteURL": "https://'${FQDN}'/chat",|g' "${CHAT_CONFIG}"
  touch "/var/log/grommunio-chat/mattermost.log"
  chown -R grochat:grochat "/etc/grommunio-chat/" "/usr/share/grommunio-chat/logs" "/usr/share/grommunio-chat/config" "/var/log/grommunio-chat" "/var/lib/grommunio-chat/"
  chmod 644 ${CHAT_CONFIG}
  systemctl enable grommunio-chat
  systemctl restart grommunio-chat

  # wait for the grommunio-chat unix socket, sometimes a second restart required for bind (db population)
  if ! [ -e "/var/tmp/grommunio-chat_local.socket" ] ; then
    systemctl restart grommunio-chat
    for n in $(seq 1 10) ; do
      [ -e "/var/tmp/grommunio-chat_local.socket" ] && break
      sleep 3
    done
  fi
  pushd /usr/share/grommunio-chat/ || return
    MMCTL_LOCAL_SOCKET_PATH=/var/tmp/grommunio-chat_local.socket bin/grommunio-chat-ctl --local user create --email admin@localhost --username admin --password "${CHAT_ADMIN_PASS}" --system-admin >>"${LOGFILE}" 2>&1
  popd || return

  if [ "${SSL_INSTALL_TYPE}" = "0" ] || [ "${SSL_INSTALL_TYPE}" = "1" ] ; then
	generate_admin_chat_conf "/etc/grommunio-admin-api/conf.d/chat.yaml"
  fi

  chmod 640 ${CHAT_CONFIG}
  jq '.chatWebAddress |= "https://'${FQDN}'/chat"' /tmp/config.json > /tmp/config-new.json
  mv /tmp/config-new.json /tmp/config.json

fi

systemctl enable redis@grommunio.service gromox-delivery.service gromox-event.service \
  gromox-http.service gromox-imap.service gromox-midb.service gromox-pop3.service \
  gromox-delivery-queue.service gromox-timer.service gromox-zcore.service grommunio-antispam.service \
  php-fpm.service nginx.service grommunio-admin-api.service saslauthd.service mariadb >>"${LOGFILE}" 2>&1

if [ -d /etc/php8 ]; then
  if [ -e "/etc/php8/fpm/php-fpm.conf.default" ] ; then
    mv /etc/php8/fpm/php-fpm.conf.default /etc/php8/fpm/php-fpm.conf
  fi
  cp -f /usr/share/gromox/fpm-gromox.conf.sample /etc/php8/fpm/php-fpm.d/gromox.conf
elif [ -d /etc/php7 ]; then
  if [ -e "/etc/php7/fpm/php-fpm.conf.default" ] ; then
    mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
  fi
  cp -f /usr/share/gromox/fpm-gromox.conf.sample /etc/php7/fpm/php-fpm.d/gromox.conf
fi
setconf /etc/gromox/http.cfg listen_port 10080
setconf /etc/gromox/http.cfg http_support_ssl true
setconf /etc/gromox/http.cfg listen_ssl_port 10443
setconf /etc/gromox/http.cfg host_id ${FQDN}

setconf /etc/gromox/smtp.cfg listen_port 24

cp /etc/pam.d/smtp /etc/pam.d/smtp.save
cp /home/config/smtp /etc/pam.d/smtp

echo "# Do not delete this file unless you know what you do!" > /etc/grommunio-common/setup_done

# Set up autodiscover
cp /home/config/autodiscover.ini /etc/gromox/autodiscover.ini 

setconf /etc/gromox/autodiscover.ini host ${MYSQL_HOST} 
setconf /etc/gromox/autodiscover.ini username ${MYSQL_USER}
setconf /etc/gromox/autodiscover.ini password ${MYSQL_PASS}
setconf /etc/gromox/autodiscover.ini dbname ${MYSQL_DB}

setconf /etc/gromox/autodiscover.ini organization ${ORGANIZATION}
#setconf /etc/gromox/autodiscover.ini hostname ${FQDN}
setconf /etc/gromox/autodiscover.ini mapihttp 1

setconf /etc/gromox/autodiscover.ini timezone ${TIMEZONE}
setconf /etc/gromox/autodiscover.ini /var/lib/gromox/user ${HTTP_PROXY_USER}
setconf /etc/gromox/autodiscover.ini /var/lib/gromox/domain ${HTTP_PROXY_DOMAIN}

# Set up http.cfg
setconf /etc/gromox/http.cfg listen_port 10080
setconf /etc/gromox/http.cfg http_support_ssl true
setconf /etc/gromox/http.cfg listen_ssl_port 10443
setconf /etc/gromox/http.cfg host_id ${FQDN}

grommunio-admin passwd --password "${ADMIN_PASS}" >>"${LOGFILE}" 2>&1

rspamadm pw -p "${ADMIN_PASS}" | sed -e 's#^#password = "#' -e 's#$#";#' > /etc/grommunio-antispam/local.d/worker-controller.inc

setconf /etc/gromox/http.cfg http_certificate_path "${SSL_BUNDLE_T}"
setconf /etc/gromox/http.cfg http_private_key_path "${SSL_KEY_T}"

setconf /etc/gromox/imap.cfg imap_support_starttls true
setconf /etc/gromox/imap.cfg listen_ssl_port 993
setconf /etc/gromox/imap.cfg imap_certificate_path "${SSL_BUNDLE_T}"
setconf /etc/gromox/imap.cfg imap_private_key_path "${SSL_KEY_T}"

setconf /etc/gromox/pop3.cfg pop3_support_stls true
setconf /etc/gromox/pop3.cfg listen_ssl_port 995
setconf /etc/gromox/pop3.cfg pop3_certificate_path "${SSL_BUNDLE_T}"
setconf /etc/gromox/pop3.cfg pop3_private_key_path "${SSL_KEY_T}"

cp /home/config/certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 
ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf
chown gromox:gromox /etc/grommunio-common/ssl/*

# Domain and X500
for SERVICE in http midb zcore imap pop3 smtp delivery ; do
  setconf /etc/gromox/${SERVICE}.cfg default_domain "${DOMAIN}"
done
for CFG in midb.cfg zcore.cfg exmdb_local.cfg exmdb_provider.cfg exchange_emsmdb.cfg exchange_nsp.cfg ; do
  setconf "/etc/gromox/${CFG}" x500_org_name "${X500}"
done

generate_g_cf_files "/etc/postfix/grommunio-virtual-mailbox-domains.cf" "SELECT 1 FROM domains WHERE domain_status=0 AND domainname='%s'"
generate_g_cf_files "/etc/postfix/grommunio-virtual-mailbox-alias-maps.cf" "SELECT mainname FROM aliases WHERE aliasname='%s' UNION select destination FROM forwards WHERE username='%s' AND forward_type = 1"
generate_g_cf_files "/etc/postfix/grommunio-virtual-mailbox-maps.cf" "SELECT 1 FROM users WHERE username='%s'"
generate_g_cf_files "/etc/postfix/grommunio-bcc-forwards.cf" "SELECT destination FROM forwards WHERE username='%s' AND forward_type = 0"

postconf -e \
  myhostname="${FQDN}" \
  virtual_mailbox_domains="mysql:/etc/postfix/grommunio-virtual-mailbox-domains.cf" \
  virtual_mailbox_maps="mysql:/etc/postfix/grommunio-virtual-mailbox-maps.cf" \
  virtual_alias_maps="mysql:/etc/postfix/grommunio-virtual-mailbox-alias-maps.cf" \
  recipient_bcc_maps="mysql:/etc/postfix/grommunio-bcc-forwards.cf" \
  unverified_recipient_reject_code=550 \
  virtual_transport="smtp:[::1]:24" \
  relayhost="${RELAYHOST}" \
  inet_interfaces=all \
  smtpd_helo_restrictions=permit_mynetworks,permit_sasl_authenticated,reject_invalid_hostname,reject_non_fqdn_hostname \
  smtpd_sender_restrictions=reject_non_fqdn_sender,permit_sasl_authenticated,permit_mynetworks \
  smtpd_recipient_restrictions=permit_sasl_authenticated,permit_mynetworks,reject_unknown_recipient_domain,reject_non_fqdn_hostname,reject_non_fqdn_sender,reject_non_fqdn_recipient,reject_unauth_destination,reject_unauth_pipelining \
  smtpd_data_restrictions=reject_unauth_pipelining \
  smtpd_discard_ehlo_keywords=chunking \
  smtpd_tls_security_level=may \
  smtpd_tls_auth_only=no \
  smtpd_tls_cert_file="${SSL_BUNDLE_T}" \
  smtpd_tls_key_file="${SSL_KEY_T}" \
  smtpd_tls_received_header=yes \
  smtpd_tls_session_cache_timeout=3600s \
  smtpd_use_tls=yes \
  tls_random_source=dev:/dev/urandom \
  smtpd_sasl_auth_enable=yes \
  broken_sasl_auth_clients=yes \
  smtpd_sasl_security_options=noanonymous \
  smtpd_sasl_local_domain=\
  smtpd_milters=inet:localhost:11332 \
  milter_default_action=accept \
  smtp_tls_security_level=may \
  smtp_use_tls=yes \
  milter_protocol=6
postconf -M tlsmgr/unix="tlsmgr unix - - n 1000? 1 tlsmgr"
postconf -M submission/inet="submission inet n - n - - smtpd"
postconf -P submission/inet/syslog_name="postfix/submission"
postconf -P submission/inet/smtpd_tls_security_level=encrypt
postconf -P submission/inet/smtpd_sasl_auth_enable=yes
postconf -P submission/inet/smtpd_relay_restrictions=permit_sasl_authenticated,reject
postconf -P submission/inet/milter_macro_daemon_name=ORIGINATING

systemctl enable postfix.service >>"${LOGFILE}" 2>&1
systemctl restart postfix.service >>"${LOGFILE}" 2>&1

systemctl enable grommunio-fetchmail.timer >>"${LOGFILE}" 2>&1
systemctl start grommunio-fetchmail.timer >>"${LOGFILE}" 2>&1

{
  firewall-cmd --add-service=https --zone=public --permanent
  firewall-cmd --add-port=25/tcp --zone=public --permanent
  firewall-cmd --add-port=80/tcp --zone=public --permanent
  firewall-cmd --add-port=110/tcp --zone=public --permanent
  firewall-cmd --add-port=143/tcp --zone=public --permanent
  firewall-cmd --add-port=587/tcp --zone=public --permanent
  firewall-cmd --add-port=993/tcp --zone=public --permanent
  firewall-cmd --add-port=995/tcp --zone=public --permanent
  firewall-cmd --add-port=8080/tcp --zone=public --permanent
  firewall-cmd --add-port=8443/tcp --zone=public --permanent
  firewall-cmd --reload
} >>"${LOGFILE}" 2>&1

systemctl restart redis@grommunio.service nginx.service php-fpm.service gromox-delivery.service \
  gromox-event.service gromox-http.service gromox-imap.service gromox-midb.service \
  gromox-pop3.service gromox-delivery-queue.service gromox-timer.service gromox-zcore.service \
  grommunio-admin-api.service saslauthd.service grommunio-antispam.service >>"${LOGFILE}" 2>&1

if [[ $ENABLE_FILES = true ]] ; then

cat > /usr/share/grommunio-common/nginx/locations.d/grommunio-files.conf <<EOF
location ^~ /files {
	proxy_pass https://${OFFICE_HOST}:443/files;
	proxy_request_buffering off;
	proxy_buffering off;
	error_log /var/log/nginx/nginx-files-error.log;
	access_log /var/log/nginx/nginx-files-access.log;
}
EOF

fi

if [[ $ENABLE_OFFICE = true ]] ; then

cat > /usr/share/grommunio-common/nginx/locations.d/grommunio-office.conf <<EOF
location  /cache/ {
  rewrite /cache/(.*)$ /office/cache/\$1;
}
location  /office/ {
  proxy_pass         https://${OFFICE_HOST}:443/office/;
  proxy_http_version 1.1;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection \$proxy_connection;
  proxy_set_header X-Forwarded-Host \$the_host/office;
  proxy_set_header X-Forwarded-Proto \$the_scheme;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  access_log /var/log/nginx/nginx-office-access.log;
  error_log /var/log/nginx/nginx-office-error.log;
}
EOF

fi

if [[ $ENABLE_ARCHIVE = true ]] ; then

  echo "/(.*)/   prepend X-Envelope-To: \$1" > /etc/postfix/grommunio-archiver-envelope.cf
  postconf -e "smtpd_recipient_restrictions=permit_sasl_authenticated,permit_mynetworks,check_recipient_access pcre:/etc/postfix/grommunio-archiver-envelope.cf,reject_unknown_recipient_domain,reject_non_fqdn_hostname,reject_non_fqdn_sender,reject_non_fqdn_recipient,reject_unauth_destination,reject_unauth_pipelining"

  postconf -e "always_bcc=archive@${FQDN}"
  echo "archive@${FQDN} smtp:[gromox-archive]:2693" > /etc/postfix/transport
  postmap /etc/postfix/transport

# configuration file /usr/share/grommunio-common/nginx/upstreams.d/grommunio-archive.conf:
cat >  /usr/share/grommunio-common/nginx/upstreams.d/grommunio-archive.conf <<EOF
upstream gromoxarchive {
	server ${ARCHIVE_HOST}:443;
}
EOF

# configuration file /usr/share/grommunio-common/nginx/locations.d/grommunio-archive.conf:
cat > /usr/share/grommunio-common/nginx/locations.d/grommunio-archive.conf <<EOF
location /archive {
	proxy_pass https://gromoxarchive/archive;
	proxy_request_buffering off;
	proxy_buffering off;
	error_log /var/log/nginx/nginx-archive-error.log;
	access_log /var/log/nginx/nginx-archive-access.log;
}

location ~* ^/archive/(qr|js|sso|index).php {
	proxy_pass https://gromoxarchive;
	proxy_request_buffering off;
	proxy_buffering off;
	error_log /var/log/nginx/nginx-archive-error.log;
	access_log /var/log/nginx/nginx-archive-access.log;
}

location ~* ^/archive/(.+\.php)(/|$)$ {
        rewrite /archive/search.php /archive/index.php?route=search/search&type=simple;
        rewrite /archive/advanced.php /archive/index.php?route=search/search&type=advanced;
        rewrite /archive/expert.php /archive/index.php?route=search/search&type=expert;
        rewrite /archive/search-helper.php /archive/index.php?route=search/helper;
        rewrite /archive/audit-helper.php /archive/index.php?route=audit/helper;
        rewrite /archive/message.php /archive/index.php?route=message/view;
        rewrite /archive/bulkrestore.php /archive/index.php?route=message/bulkrestore;
        rewrite /archive/bulkremove.php /archive/index.php?route=message/bulkremove;
        rewrite /archive/rejectremove.php /archive/index.php?route=message/rejectremove;
        rewrite /archive/bulkpdf.php /archive/index.php?route=message/bulkpdf;
        rewrite /archive/folders.php /archive/index.php?route=folder/list&;
        rewrite /archive/settings.php /archive/index.php?route=user/settings;
        rewrite /archive/login.php /archive/index.php?route=login/login;
        rewrite /archive/logout.php /archive/index.php?route=login/logout;
        rewrite /archive/google.php /archive/index.php?route=login/google;
        rewrite /archive/domain.php /archive/index.php?route=domain/domain;
        rewrite /archive/ldap.php /archive/index.php?route=ldap/list;
        rewrite /archive/customer.php /archive/index.php?route=customer/list;
        rewrite /archive/retention.php /archive/index.php?route=policy/retention;
        rewrite /archive/archiving.php /archive/index.php?route=policy/archiving;
        rewrite /archive/legalhold.php /archive/index.php?route=policy/legalhold;
}

location ~* /archive/view/javascript/piler.js$ {
        rewrite /archive/view/javascript/piler.js /archive/js.php;
}

location ^~ /view {
	proxy_pass https://gromoxarchive;
	proxy_request_buffering off;
	proxy_buffering off;
	error_log /var/log/nginx/nginx-archive-error.log;
	access_log /var/log/nginx/nginx-archive-access.log;
}
EOF

fi

mv /tmp/config.json /etc/grommunio-admin-common/config.json
systemctl restart grommunio-admin-api.service nginx.service
setup_done

exit 0
