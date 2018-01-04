FROM centos:6.6

# setting right timezone
ENV TIMEZONE="Europe/Moscow"

# this is official bitrix-env install script for centos, but with my custom option to choose php version
ADD bitrix-env.sh /tmp/
RUN chmod +x /tmp/bitrix-env.sh
RUN /tmp/bitrix-env.sh && yum install -y openssh-server nano mc htop zip unzip screen wget && wget https://dl.yarnpkg.com/rpm/yarn.repo -O /etc/yum.repos.d/yarn.repo && curl --silent --location https://rpm.nodesource.com/setup_6.x | bash - && yum install -y yarn && yarn global add gulp

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