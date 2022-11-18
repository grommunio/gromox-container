#!/bin/sh -e

if [ -f /etc/php7/fpm/php-fpm.conf.default ]; then
	mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
fi

ln -s /home/gromox-services/* /etc/gromox/
ln -s /home/nginx/ss_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf
chown root:gromox /etc/gromox  
chmod 775 /etc/gromox 
