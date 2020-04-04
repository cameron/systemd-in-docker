# some bits borrowed from https://github.com/alehaa/docker-debian-systemd/blob/master/Dockerfile

FROM debian:buster

# libsecret-1-dev is for the twilio cli
RUN apt-get -y upgrade && \
    apt-get -y update && \
    apt-get -y install \
            libsecret-1-dev \
            curl \
            less \
            man \
            git \
            make \
            build-essential \
            systemd \
            systemd-sysv \
            procps

# Configure systemd.
#
# For running systemd inside a Docker container, some additional tweaks are
# required. For a detailed list see:
#
# https://developers.redhat.com/blog/2016/09/13/ \
#   running-systemd-in-a-non-privileged-container/
#
# Additional tweaks will be applied in the final image below.

# To avoid ugly warnings when running this image on a host running systemd, the
# following units will be masked.
#
# NOTE: This will not remove ALL warnings in all Debian releases, but seems to
#       work for stretch.
RUN systemctl mask --   \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount

# The machine-id should be generated when creating the container. This will be
# done automatically if the file is not present, so let's delete it.
RUN rm -f           \
    /etc/machine-id \
    /var/lib/dbus/machine-id

# Configure systemd.
#
# For running systemd inside a Docker container, some additional tweaks are
# required. Some of them have already been applied above.
#
# The 'container' environment variable tells systemd that it's running inside a
# Docker container environment.
ENV container docker

# A different stop signal is required, so systemd will initiate a shutdown when
# running 'docker stop <container>'.
STOPSIGNAL SIGRTMIN+3


RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp*

# entr
RUN git clone https://github.com/eradman/entr
WORKDIR entr
RUN ./configure
RUN make test
RUN make install
WORKDIR /
RUN rm -r entr

# node
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs

RUN npm install twilio-cli -g

ADD . /src
RUN ln -s /src/monitor.service /etc/systemd/system/


# As this image should run systemd, the default command will be changed to start
# the init system. CMD will be preferred in favor of ENTRYPOINT, so one may
# override it when creating the container to e.g. to run a bash console instead.
CMD ["/lib/systemd/systemd"]
