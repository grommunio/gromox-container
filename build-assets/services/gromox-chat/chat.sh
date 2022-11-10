#!/usr/bin/with-contenv sh

cd /usr/share/grommunio-chat 
LOGFILE="/var/log/grommunio-chat.log"
CHAT_CONFIG="/etc/grommunio-chat/config.json"
CHAT_DB_CON="${MARIADB_USER}:${MARIADB_PASSWORD}@tcp\(${DB_HOST}:3306\)\/${MARIADB_DATABASE}?charset=utf8mb4,utf8\&readTimeout=30s\&writeTimeout=30s"
sed -i 's#^.*"DataSource":.*#        "DataSource": "'${CHAT_DB_CON}'",#g' "${CHAT_CONFIG}"
sed -i 's|"SiteURL": "",|"SiteURL": "https://'${FQDN}'/chat",|g' "${CHAT_CONFIG}"
touch "/var/log/grommunio-chat/mattermost.log"
chown -R grochat:grochat "/etc/grommunio-chat/" "/usr/share/grommunio-chat/logs" "/usr/share/grommunio-chat/config" "/var/log/grommunio-chat" "/var/lib/grommunio-chat/"
chmod 644 ${CHAT_CONFIG}

/usr/bin/grommunio-chat

