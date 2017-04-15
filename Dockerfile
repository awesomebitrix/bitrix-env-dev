FROM centos:7

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

# setting default memory limit for bitrix env
WORKDIR /etc/init.d
RUN sed -i 's/memory=`free.*/memory=$\{BVAT_MEM\:\=262144\}/gi' bvat

# setting auth data for ssh
ENV SSH_PASS="bitrix"
RUN echo "bitrix:$SSH_PASS" | chpasswd

# setting right timezone
ENV TIMEZONE="Europe/Minsk"
RUN cp -f /usr/share/zoneinfo/$TIMEZONE /etc/localtime
RUN date

# starting script, when container is ready (entrypoint)
WORKDIR /
ADD container_run.sh /
RUN chmod +x /container_run.sh

ENTRYPOINT exec /container_run.sh