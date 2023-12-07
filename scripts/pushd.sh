 pushd /usr/share/grommunio-files
    rm -rf data/admin >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n maintenance:install --database=mysql --database-name=${FILES_MYSQL_DB} --database-user=${FILES_MYSQL_USER} --database-pass=${FILES_MYSQL_PASS} --admin-user=admin --admin-pass="${FILES_ADMIN_PASS}" --data-dir=/var/lib/grommunio-files/data >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set trusted_domains 1 --value="${FQDN}" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set trusted_domains 2 --value="${DOMAIN}" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set trusted_domains 3 --value="mail.${DOMAIN}" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n app:enable user_external >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set user_backends 0 arguments 0 --value="https://${FQDN}/dav" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set user_backends 0 class --value='\OCA\UserExternal\BasicAuth' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n app:enable onlyoffice >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set integrity.check.disabled --type boolean --value true >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config name 'grommunio Files' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config logo /usr/share/grommunio-files/logo.png >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config logoheader /usr/share/grommunio-files/logo.png >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config favicon /usr/share/grommunio-files/favicon.svg >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config background /usr/share/grommunio-files/background.jpg >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config disable-user-theming true >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config slogan 'filesync & sharing' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config url 'https://grommunio.com' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config color '#0072B0' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_from_address --value='admin' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_smtpmode --value='sendmail' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_sendmailmode --value='smtp' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_domain --value="${DOMAIN}" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_smtphost --value='localhost' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_smtpport --value='25' >>"${LOGFILE}" 2>&1
  popd || return