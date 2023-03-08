#!/usr/bin/with-contenv sh 

# php-fpm
if [ -f /etc/php7/fpm/php-fpm.conf.default ]; then
	echo "Creating PHP7 FPM configuration"
	mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
fi

if [ -f /etc/php8/fpm/php-fpm.conf.default ]; then
	echo "Creating PHP8 FPM configuration"
	mv /etc/php8/fpm/php-fpm.conf.default /etc/php8/fpm/php-fpm.conf
fi

# Gromox-nginx
if [ ! -f /etc/grommunio-common/nginx/ssl_certificate.conf ]; then
	echo "Linking SSL certificate to Nginx config"
	ln -s /home/nginx/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf
fi


# Gromox-admin
if [ ! -f /etc/grommunio-admin-common/nginx-ssl.conf ]; then
	echo "Linking SSL certificate to Admin config"
	ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf
fi

echo "Setting admin password"
grommunio-admin passwd -p $ADMIN_PASS 

echo "Linking admin api config"
ln -sf /home/plugins/conf.yaml /etc/grommunio-admin-api/conf.d/conf.yaml 

echo "Calling links config script"
/home/links/config.sh 

echo "Linking web config"
ln -sf /home/links/web-config.conf /etc/grommunio-admin-common/nginx.d/web-config.conf 

echo "Changing api config"
sed -i 's/chmod-socket = 660/chmod-socket = 666/g' /usr/share/grommunio-admin-api/api-config.ini

# General
echo "Setting permissions on gromox and certificates"
chown root:gromox /etc/gromox  
chown root:gromox /home/certificates/cert.key
chmod 775 /etc/gromox 

echo "Linking gromox services"
ln -sf /home/gromox-services/* /etc/gromox/

# Gromox-antispam
echo "Creating antispam run directory"
mkdir -p /var/run/grommunio-antispam 

# Gromox-postfix
echo "Setting postfix configuration"
postconf -e virtual_alias_maps=mysql:/etc/postfix/g-alias.cf 
postconf -e virtual_mailbox_domains=mysql:/etc/postfix/g-virt.cf 
postconf -e virtual_transport="smtp:[localhost]:24"

echo "Finished."
exit 0
