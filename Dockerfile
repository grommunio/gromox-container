FROM opensuse/leap:15.3

RUN zypper install -y curl && \
      curl https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && \
      rpm --import gr.key && \
      zypper --non-interactive --quiet ar -C https://download.grommunio.com/community/openSUSE_Leap_15.3 grommunio && \
      zypper --gpg-auto-import-keys ref && \
      zypper -n refresh grommunio && \
      zypper in -y gromox grommunio-common mariadb-client

#COPY   ./config_files/*.cfg  /etc/gromox/

#EXPOSE 5000

# Set up PHP FPM service
#RUN mv /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf.bak && \
#       service php7.4-fpm start

CMD ["tail", "-f", "/dev/null"]
