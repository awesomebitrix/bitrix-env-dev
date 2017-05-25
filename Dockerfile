FROM centos:6.6

# setting right timezone
ENV TIMEZONE="Europe/Minsk"

# if you need php5, instead of php7, exec docker build command with "--build-arg IS_LEGACY_PHP=1"
ARG IS_LEGACY_PHP
ENV IS_LEGACY_PHP=${IS_LEGACY_PHP}

# this is official bitrix-env install script for centos, but with my custom option to choose php version
ADD bitrix-env.sh /tmp/
RUN chmod +x /tmp/bitrix-env.sh
RUN /tmp/bitrix-env.sh $IS_LEGACY_PHP

# installing ssh-server + useful apps
RUN yum install -y openssh-server nano mc htop zip unzip screen

ENV BITRIX_MAX_MEMORY=262144

# this variable is useful, when your project contains multiple site under one licence
ENV MULTISITE_ID=0

# auth data
ENV ROOT_SSH_PASS="4EyahtMj"
ENV BITRIX_SSH_PASS="XW7ur3TB"

# starting script, when container is ready (entrypoint)
WORKDIR /
ADD run.sh /
RUN chmod +x /run.sh

# run.sh will fire every time, when container has started
ENTRYPOINT exec /run.sh