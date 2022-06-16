FROM debian:11

ARG DEBIAN_FRONTEND=noninteractive

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Note: Use the pre-built packages for the different platforms available at - https://download.grommunio.com/

RUN apt-get update && apt-get install -y curl git gnupg supervisor 

ENV KEYRING=/usr/share/keyrings/grommunio.gpg

RUN curl -fsSL https://download.grommunio.com/RPM-GPG-KEY-grommunio | gpg --dearmor | tee "$KEYRING" > /dev/null

RUN echo "deb [signed-by="$KEYRING"] https://download.grommunio.com/community/Debian_11 Debian_11 main" > /etc/apt/sources.list.d/grommunio.list

RUN apt-get update && apt-get install -y gromox grommunio-common nginx mariadb-client

# Set up NGINX

WORKDIR /home/certificates

COPY ./tls_keys .

WORKDIR /

# Set up config files

COPY ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf

COPY ./config_files/mysql_adaptor.cfg /etc/gromox/mysql_adaptor.cfg

COPY ./config_files/http.cfg /etc/gromox/http.cfg

COPY ./config_files/imap.cfg /etc/gromox/imap.cfg

COPY ./config_files/pop3.cfg /etc/gromox/pop3.cfg

# Set up PHP FPM service
RUN mv /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.bak

RUN service php7.4-fpm start

CMD ["tail", "-f", "/dev/null"]

