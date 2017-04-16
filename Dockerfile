FROM centos:6.6

# installing bitrix environment
ADD http://repos.1c-bitrix.ru/yum/bitrix-env.sh /tmp/
RUN chmod +x /tmp/bitrix-env.sh
RUN sed -i 's/read version_c/version_c=5/gi' /tmp/bitrix-env.sh
RUN /tmp/bitrix-env.sh

# player patch for bitrix
RUN echo "location ^~ /bitrix/components/bitrix/player/mediaplayer/player {add_header Content-Type video/x-flv;}" >> /etc/nginx/bx/conf/bitrix.conf

# updating package data
RUN yum update -y

# installing ssh-server
RUN yum install -y openssh-server

# installing nano editor
RUN yum install -y nano

# setting up simple xdebug config, this configuration allows everyone to start xdebug session.
RUN touch /etc/php.d/15-xdebug.ini && echo "[xdebug]" >> /etc/php.d/15-xdebug.ini && echo "zend_extension='/usr/lib64/php/modules/xdebug.so'" >> /etc/php.d/15-xdebug.ini && echo "xdebug.remote_enable = 1" >> /etc/php.d/15-xdebug.ini && echo "xdebug.remote_connect_back = 1" >> /etc/php.d/15-xdebug.ini

# setting default memory limit for bitrix env machine
WORKDIR /etc/init.d
RUN sed -i 's/memory=`free.*/memory=$\{BVAT_MEM\:\=262144\}/gi' bvat

# auth data for ROOT user
ENV ROOT_SSH_PASS="123"
RUN echo "root:$ROOT_SSH_PASS" | chpasswd

# auth data for BITRIX user
ENV BITRIX_SSH_PASS="bitrix"
RUN echo "bitrix:$BITRIX_SSH_PASS" | chpasswd

# setting right timezone
ENV TIMEZONE="Europe/Minsk"
RUN cp -f /usr/share/zoneinfo/$TIMEZONE /etc/localtime

# starting script, when container is ready (entrypoint)
WORKDIR /
ADD container_run.sh /
RUN chmod +x /container_run.sh

ENTRYPOINT exec /container_run.sh