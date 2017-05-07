#!/bin/sh

trap "shutdownSystem" HUP INT QUIT KILL TERM

shutdownSystem()
{  
    # stop service and clean up here

    if [[ $NOMYSQL -ne 1 ]];
    then
        service mysqld stop
    fi

    service nginx stop
    service httpd stop
    service sshd stop
    service crond stop
}

startConfiguration()
{
    # setting memory limit for bitrix env (default: 256mb)
    sed -i "/AVAILABLE_MEMORY=/c\AVAILABLE_MEMORY=$BITRIX_MAX_MEMORY" /etc/init.d/bvat

    echo "root:$ROOT_SSH_PASS" | chpasswd
    echo "bitrix:$BITRIX_SSH_PASS" | chpasswd

    if [[ ! -z "$TIMEZONE" ]];
    then
        cp -f /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    fi

    if [[ $MULTISITE_ID -gt 0 ]];
    then
        find /etc/ -type f -exec sed -i "s/\/home\/bitrix\/www/\/home\/bitrix\/www${MULTISITE_ID}/g" {} \;
    fi

    if [[ $CYRILLIC_MODE -eq 1 ]];
    then
        sed -i '/mbstring.func_overload/c\mbstring.func_overload = 0' /etc/php.d/bitrixenv.ini
        sed -i '/mbstring.internal_encoding/c\mbstring.internal_encoding = cp1251' /etc/php.d/bitrixenv.ini
    fi
}

if [[ ! -f "/home/bitrix/containerStarted" ]];
then
    startConfiguration
    touch /home/bitrix/containerStarted
fi

# start service in background here
/etc/init.d/bvat start

if [[ $NOMYSQL -ne 1 ]];
then
    service mysqld start
fi

service crond start
service httpd start
service nginx start
service sshd start

echo "[hit enter key to exit] or run 'docker stop <container>'"
read _

shutdownSystem

echo "exited $0"