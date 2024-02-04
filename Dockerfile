# Sample container image with openSUSE Leap + Systemd
#
# Description:
#
# This image serves as a basic reference example for users looking to
# run Systemd inside a system container in order to deploy various
# services within the system container or use it as a virtual host
# environment.
#
# Usage:
#
# $ docker run --runtime=sysbox-runc -it --rm --name=syscont your-openSUSE-image
#
# This will run systemd and prompt for a user login; you can set a default user/password
# if needed.

FROM opensuse/leap:15.5

ARG GROMMUNIO_REPO=openSUSE_Leap_15.5

#
# Systemd installation
#
RUN zypper -n install \
        iptables   \
        iproute2    \
        kmod       \
        curl    \
        patterns-base-apparmor \ 
        patterns-base-base \ 
        procps  \
        sudo       \
        systemd && \

	curl https://download.grommunio.com/RPM-GPG-KEY-grommunio > gr.key && \
	  rpm --import gr.key && \
	  zypper --non-interactive --quiet ar -C https://download.grommunio.com/community/${GROMMUNIO_REPO} grommunio && \
	  zypper --gpg-auto-import-keys ref && \
	  zypper -n refresh grommunio && \

    zypper -n install docker openssh-server vim mysql gromox &&       \
    systemctl enable sshd docker &&                                  \
        

    # Unmask services
    systemctl unmask                                                  \
        systemd-remount-fs.service                                    \
        dev-hugepages.mount                                           \
        sys-fs-fuse-connections.mount                                 \
        systemd-logind.service                                        \
        getty.target                                                  \
        console-getty.service &&                                      \
    # Prevent journald from reading kernel messages from /dev/kmsg
    echo "ReadKMsg=no" >> /etc/systemd/journald.conf &&               \
                                                                      
                                                                      
    # Create default user if needed
    # useradd --create-home --shell /bin/bash your_username -G wheel && echo "your_username:your_password" | chpasswd
    groupadd 'wheel' &&                                        \
    useradd -m -s /bin/bash -G wheel admin &&                        \                         
    echo "admin:admin" | chpasswd

COPY scripts /home/scripts
COPY common /home/common
COPY config /home/config
COPY var.env /home/var.env
RUN chmod +x /home/scripts/db.sh
COPY scripts/db.service /etc/systemd/system/db.service
COPY scripts/entry.service /etc/systemd/system/entry.service
COPY entrypoint.sh /home/entrypoint.sh
RUN chmod +x /home/entrypoint.sh
#RUN sh /home/entrypoint.sh

#RUN yes | sh /home/entrypoint.sh
# Make use of stopsignal (instead of sigterm) to stop systemd containers.

# Set systemd as entrypoint.
ENTRYPOINT [ "/usr/lib/systemd/systemd", "--log-level=err" ]
