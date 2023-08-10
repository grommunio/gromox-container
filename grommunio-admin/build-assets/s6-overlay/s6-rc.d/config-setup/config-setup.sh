#!/usr/bin/with-contenv sh 

LOG_PREFIX="[config-setup]"

# php-fpm
if [ -f /etc/php7/fpm/php-fpm.conf.default ]; then
	echo "$LOG_PREFIX Creating PHP7 FPM configuration"
	mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
fi

if [ -f /etc/php8/fpm/php-fpm.conf.default ]; then
	echo "$LOG_PREFIX Creating PHP8 FPM configuration"
	mv /etc/php8/fpm/php-fpm.conf.default /etc/php8/fpm/php-fpm.conf
fi

# Gromox-nginx
if [ ! -f /etc/grommunio-common/nginx/ssl_certificate.conf ]; then
	echo "$LOG_PREFIX Linking SSL certificate to Nginx config"
	ln -s /home/nginx/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf
fi


# Gromox-admin
if [ ! -f /etc/grommunio-admin-common/nginx-ssl.conf ]; then
	echo "$LOG_PREFIX Linking SSL certificate to Admin config"
	ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf
fi

echo "$LOG_PREFIX Setting gromox folder permissions"
chown gromox:gromox /var/lib/gromox
chmod a+rwX /var/lib/gromox

echo "$LOG_PREFIX Setting admin password"
grommunio-admin passwd -p $ADMIN_PASS 

echo "$LOG_PREFIX Linking admin api config"
ln -sf /home/plugins/conf.yaml /etc/grommunio-admin-api/conf.d/conf.yaml 

echo "$LOG_PREFIX Calling links config script"
chmod +x /home/links/config.sh 
/home/links/config.sh 

echo "$LOG_PREFIX Linking web config"
ln -sf /home/links/web-config.conf /etc/grommunio-admin-common/nginx.d/web-config.conf 

echo "$LOG_PREFIX Changing api config"
sed -i 's/chmod-socket = 660/chmod-socket = 666/g' /usr/share/grommunio-admin-api/api-config.ini

echo "$LOG_PREFIX Finished."
exit 0
