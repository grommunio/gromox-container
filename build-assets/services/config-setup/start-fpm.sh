#!/bin/sh -e

if [ -f /etc/php7/fpm/php-fpm.conf.default ]; then
	mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
fi

ln -s /home/gromox-services/* /etc/gromox/ 
