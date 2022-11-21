#!/bin/sh -e

if [ -f /etc/php7/fpm/php-fpm.conf.default ]; then
	mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
fi

ln -s /home/gromox-services/* /etc/gromox/

if [ -f /etc/grommunio-common/nginx/ssl_certificate.conf ]; then
	ln -s /home/nginx/ss_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf
fi


if [ -f /etc/grommunio-admin-common/nginx-ssl.conf]; then
	ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf
fi

chown root:gromox /etc/gromox  
chmod 775 /etc/gromox 
