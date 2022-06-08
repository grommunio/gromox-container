FROM debian:11

ARG DEBIAN_FRONTEND=noninteractive

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Note: Use the pre-built packages for the different platforms available at - https://download.grommunio.com/

RUN apt-get update && apt-get install -y curl git gnupg 

ENV KEYRING=/usr/share/keyrings/grommunio.gpg

RUN curl -fsSL https://download.grommunio.com/RPM-GPG-KEY-grommunio | gpg --dearmor | tee "$KEYRING" > /dev/null

RUN echo "deb [signed-by="$KEYRING"] https://download.grommunio.com/community/Debian_11 Debian_11 main" > /etc/apt/sources.list.d/grommunio.list

RUN apt-get update && apt-get install -y gromox grommunio-common nginx mariadb-client

# Set up NGINX

WORKDIR /certificates

COPY ./tls_keys .

WORKDIR /

COPY ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf

# Set up DB

COPY ./config_files/mysql_adaptor.cfg /etc/gromox/mysql_adaptor.cfg

#RUN gromox-dbop -C

ENTRYPOINT ["tail", "-f", "/dev/null"]


# Create a nginx container, maria db container and gromox container 
# Put these on the same network 

#RUN apt-get install -y nginx #nginx-module-vts

#RUN systemctl enable nginx && systemctl start nginx


