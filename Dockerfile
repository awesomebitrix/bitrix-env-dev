FROM centos:6.6

# setting right timezone
ENV TIMEZONE="Europe/Minsk"
RUN cp -f /usr/share/zoneinfo/$TIMEZONE /etc/localtime

# if you need php5, instead of php7, exec docker build command with "--build-arg IS_LEGACY_PHP=1"
ARG IS_LEGACY_PHP
ENV IS_LEGACY_PHP=${IS_LEGACY_PHP}

# this is official bitrixvm install script for centos, but with my custom option to choose php version
ADD bitrix-env.sh /tmp/
RUN chmod +x /tmp/bitrix-env.sh
RUN /tmp/bitrix-env.sh $IS_LEGACY_PHP

# setting up simple xdebug config, this configuration allows everyone to start xdebug session.
RUN touch /etc/php.d/15-xdebug.ini && echo "[xdebug]" >> /etc/php.d/15-xdebug.ini && echo "zend_extension='/usr/lib64/php/modules/xdebug.so'" >> /etc/php.d/15-xdebug.ini && echo "xdebug.remote_enable = 1" >> /etc/php.d/15-xdebug.ini && echo "xdebug.remote_connect_back = 1" >> /etc/php.d/15-xdebug.ini

# setting memory limit for bitrixvm (apache, mysql, etc)
WORKDIR /etc/init.d
RUN sed -i '/AVAILABLE_MEMORY=$(free/c\AVAILABLE_MEMORY=262144' bvat

# installing ssh-server and nano-editor
RUN yum install -y openssh-server nano mc

# this variable is useful, when your project contains multiple site under one licence
ENV MULTISITE_ID=0

# setting new bitrix password for mysql
ENV BITRIX_DB_PASS="123"

# auth data
ENV ROOT_SSH_PASS="123"
ENV BITRIX_SSH_PASS="123"
RUN echo "root:$ROOT_SSH_PASS" | chpasswd && echo "bitrix:$BITRIX_SSH_PASS" | chpasswd

# starting script, when container is ready (entrypoint)
WORKDIR /
ADD run.sh /
RUN chmod +x /run.sh

# run.sh will fire every container start
ENTRYPOINT exec /run.sh