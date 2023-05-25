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


# General
echo "$LOG_PREFIX Setting permissions on gromox and certificates"
chown root:gromox /etc/gromox  
chown root:gromox /home/certificates/cert.key
chmod 775 /etc/gromox 

echo "$LOG_PREFIX Setting permissions on gromox socket folder"
mkdir -p /run/gromox
chown gromox:gromox /run/gromox

echo "$LOG_PREFIX Linking gromox services"
ln -sf /home/gromox-services/* /etc/gromox/

# Gromox-antispam
echo "$LOG_PREFIX Creating antispam run directory"
mkdir -p /var/run/grommunio-antispam 

echo "$LOG_PREFIX Finished."
exit 0
