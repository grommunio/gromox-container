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

WORKDIR /certificates

COPY ./tls_keys .

WORKDIR /

# Set up config files

COPY ./config_files/ssl_certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf

COPY ./config_files/mysql_adaptor.cfg /etc/gromox/mysql_adaptor.cfg

COPY ./config_files/timer.cfg /etc/gromox/timer.cfg

COPY ./config_files/http.cfg /etc/gromox/http.cfg

COPY ./config_files/imap.cfg /etc/gromox/imap.cfg

COPY ./config_files/pop3.cfg /etc/gromox/pop3.cfg

# Set up DB
# Run an ephemeral container to populate this data. Use the command below as entrypoint
#ENTRYPOINT["gromox-dbop", "-C"]

# For timer; timer must run with gromox-http. We need more than one process in the container
#ENTRYPOINT ["/bin/bash", "/usr/libexec/gromox/timer", "&"]

# For gromox-http
#ENTRYPOINT ["/bin/bash", "/usr/libexec/gromox/http", "&"]

# For gromox-imap
#ENTRYPOINT ["/bin/bash", "/usr/libexec/gromox/imap", "&"]

# For gromox-pop3
#ENTRYPOINT ["/bin/bash", "/usr/libexec/gromox/pop3", "&"]

ENTRYPOINT ["tail", "-f", "/dev/null"]

