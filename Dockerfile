FROM debian:11-slim

ARG DEBIAN_FRONTEND=noninteractive

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN apt-get update && apt-get install -y curl git gnupg supervisor 

ENV KEYRING=/usr/share/keyrings/grommunio.gpg

RUN curl -fsSL https://download.grommunio.com/RPM-GPG-KEY-grommunio | gpg --dearmor | tee "$KEYRING" > /dev/null && \
      echo "deb [signed-by="$KEYRING"] https://download.grommunio.com/community/Debian_11 Debian_11 main" > /etc/apt/sources.list.d/grommunio.list && \
      apt-get update && apt-get install -y gromox grommunio-common nginx mariadb-client

# Set up NGINX

#WORKDIR /home/certificates

#COPY ./tls_keys .

#WORKDIR /

# Set up config files

COPY   ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 

COPY   ./config_files/gromox.conf /usr/share/grommunio-common/nginx/upstreams.d/gromox.conf

COPY   ./config_files/*.cfg  /etc/gromox/

COPY   ./config_files/g-alias.cf ./config_files/g-virt.cf /etc/postfix/ 

# Set up PHP FPM service
RUN mv /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.bak && \
       service php7.4-fpm start

EXPOSE 5000

CMD ["tail", "-f", "/dev/null"]
