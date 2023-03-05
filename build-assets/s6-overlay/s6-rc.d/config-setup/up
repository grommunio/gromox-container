#!/usr/bin/with-contenv sh 

# php-fpm
if [ -f /etc/php7/fpm/php-fpm.conf.default ]; then
	mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
fi


# Gromox-nginx
if [ ! -f /etc/grommunio-common/nginx/ssl_certificate.conf ]; then
	ln -s /home/nginx/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf
fi


# Gromox-admin
if [ ! -f /etc/grommunio-admin-common/nginx-ssl.conf ]; then
	ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf
fi
grommunio-admin passwd -p $ADMIN_PASS 
ln -sf /home/plugins/conf.yaml /etc/grommunio-admin-api/conf.d/conf.yaml 
/home/links/config.sh 
ln -sf /home/links/web-config.conf /etc/grommunio-admin-common/nginx.d/web-config.conf 

# General
chown root:gromox /etc/gromox  
chmod 775 /etc/gromox 
ln -sf /home/gromox-services/* /etc/gromox/

# Gromox-antispam
mkdir -p /var/run/grommunio-antispam 

# Gromox-postfix
postconf -e virtual_alias_maps=mysql:/etc/postfix/g-alias.cf 
postconf -e virtual_mailbox_domains=mysql:/etc/postfix/g-virt.cf 
postconf -e virtual_transport="smtp:[localhost]:24"

exit 0
