FROM debian:11

ARG DEBIAN_FRONTEND=noninteractive

#ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Note that random password was set for slapd ldap-utils

RUN apt-get update && apt-get install -y autotools-dev build-essential \
                                         git libjsoncpp-dev libgumbo-dev \
                                         libhx-dev libmariadb3 libmariadb-dev \
                                         openssl sqlite3 libtinyxml2-8 \
                                         zlib1g autoconf curl slapd ldap-utils

# Note: Use the pre-built packages for the different platforms available at - https://download.grommunio.com/

RUN echo "deb [trusted=yes] https://download.grommunio.com/community/Debian_11 Debian_11 main" > /etc/apt/sources.list.d/grommunio.list

RUN curl https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && apt-key add gr-key && apt-get update 

RUN apt-get install -y apt-transport-https lsb-release ca-certificates \
                     php7.4 php7.4-cli php7.4-cgi php7.4-fpm php7.4-gd  \
                     php7.4-mysql php7.4-imap php7.4-curl php7.4-intl \ 
                     php7.4-pspell php7.4-sqlite3 php7.4-tidy php7.4-xsl \ 
                     php7.4-zip php7.4-mbstring php7.4-soap php7.4-opcache \ 
                     libonig5 php7.4-common php7.4-readline php7.4-xml 

WORKDIR /home

RUN curl -OL https://github.com/Kitware/CMake/releases/download/v3.23.2/cmake-3.23.2-linux-x86_64.tar.gz 

RUN tar -xvf cmake-3.23.2-linux-x86_64.tar.gz

ENV PATH=/home/cmake-3.23.2-linux-x86_64/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /home

RUN git clone https://github.com/fmtlib/fmt.git

WORKDIR fmt

RUN mkdir build && cd build && cmake .. && make && make install 



# Install fmt >= 8 (included in distro), Linux-PAM (included in distro), OpenLDAP




