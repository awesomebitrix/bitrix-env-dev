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

startConfigurationTask()
{
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

    if [[ $NOMYSQL -ne 1 ]];
    then
        service mysqld start

        # setting new password for mysql + allowing to connect internal mysql-server from outside
        mysql -u root -e "use mysql; UPDATE user SET password=PASSWORD('$BITRIX_DB_PASS') WHERE User='bitrix'; flush privileges; GRANT ALL ON *.* to bitrix@'%' IDENTIFIED BY '$BITRIX_DB_PASS'; GRANT ALL ON *.* to bitrix@'localhost' IDENTIFIED BY '$BITRIX_DB_PASS';"

        if [[ ! -z "$DB_NAME" ]];
        then
            mysql -u bitrix -p$BITRIX_DB_PASS -e "create database $DB_NAME $DB_ADDITIONAL_PARAMS";
        fi

        service mysqld stop
    fi
}

if [[ ! -f "/home/bitrix/containerStarted" ]];
then
    startConfigurationTask
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

echo "root:$ROOT_SSH_PASS" | chpasswd
echo "bitrix:$BITRIX_SSH_PASS" | chpasswd

echo "[hit enter key to exit] or run 'docker stop <container>'"
read _

shutdownSystem

echo "exited $0"