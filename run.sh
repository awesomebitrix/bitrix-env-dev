#!/bin/sh

trap "shutdownSystem" HUP INT QUIT KILL TERM

shutdownSystem()
{  
    # stopping services (docker stop)

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
    # timezone configuration
    cp -f /usr/share/zoneinfo/$TIMEZONE /etc/localtime

    # setting memory limit for bitrix env (default: 256mb)
    sed -i "/AVAILABLE_MEMORY=/c\AVAILABLE_MEMORY=$BITRIX_MAX_MEMORY" /etc/init.d/bvat

    # mail configuration
    mkdir /home/bitrix/mail
    chown -R bitrix:bitrix /home/bitrix/mail
    sed -i "/sendmail_path/c\sendmail_path = /bin/cat > \"/home/bitrix/mail/mail_\`date +\%Y-\%m-\%d_\%H-\%M-\%S\`\"" /etc/php.d/bitrixenv.ini

    # ssh configuration
    echo "root:$ROOT_SSH_PASS" | chpasswd
    echo "bitrix:$BITRIX_SSH_PASS" | chpasswd

    # setting up simple xdebug config, this configuration allows everyone to start xdebug session.
    if [[ "$XDEBUG" -eq 1 ]];
    then
        echo "[xdebug]" > /etc/php.d/15-xdebug.ini && echo "zend_extension='/usr/lib64/php/modules/xdebug.so'" >> /etc/php.d/15-xdebug.ini && echo "xdebug.remote_enable = 1" >> /etc/php.d/15-xdebug.ini && echo "xdebug.remote_connect_back = 1" >> /etc/php.d/15-xdebug.ini && echo "xdebug.remote_autostart = 0" >> /etc/php.d/15-xdebug.ini
    fi

    # multisite configuration
    if [[ "$MULTISITE_ID" -gt 1 ]];
    then
        find /etc/ -type f -exec sed -i "s/\/home\/bitrix\/www/\/home\/bitrix\/www${MULTISITE_ID}/g" {} \;
    fi

    # cyrillic encoding configuration (windows-1251)
    if [[ "$CYRILLIC_MODE" -eq 1 ]];
    then
        sed -i '/mbstring.func_overload/c\mbstring.func_overload = 0' /etc/php.d/bitrixenv.ini
        sed -i '/mbstring.internal_encoding/c\mbstring.internal_encoding = cp1251' /etc/php.d/bitrixenv.ini
    fi
}

# starConfiguration function starts only once
if [[ ! -f "/home/bitrix/configurationComplete" ]];
then
    startConfiguration
    touch /home/bitrix/configurationComplete
fi

# starting services (docker run, docker start)
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