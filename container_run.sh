#!/bin/sh

trap "shutdownSystem" HUP INT QUIT KILL TERM

shutdownSystem()
{  
	# stop service and clean up here

	if [[ $NOMYSQL == 1 ]];
	then
	    echo "Internal MySQL is offline (NOMYSQL=1)"
	else
	    service mysqld stop
	fi

	service nginx stop
	service httpd stop
	service sshd stop
	service crond stop
}

# start service in background here
# memory=${BVAT_MEM:=262144}

/etc/init.d/bvat start

if [[ $NOMYSQL == 1 ]];
then
    echo "Internal MySQL is offline. Use your own DB-server instead... (NOMYSQL=1)"
else
    service mysqld start
fi

if [ ! -z "$TIMEZONE" ];
then
    cp -f /usr/share/zoneinfo/$TIMEZONE /etc/localtime 
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