#!/bin/bash

# variables
LOG=$(mktemp /tmp/bitrix-env-XXXXX.log)
RELEASE_FILE=/etc/redhat-release
OS=$(awk '{print $1}' $RELEASE_FILE)
MYSQL_CNF=$HOME/.my.cnf

DEFAULT_SITE=/home/bitrix/www
[[ -z $SILENT ]] && SILENT=0
[[ -z $TEST_REPOSITORY ]] && TEST_REPOSITORY=0

# common subs
print(){
    msg=$1
    notice=${2:-0}
    [[ ( $SILENT -eq 0 ) && ( $notice -eq 1 ) ]] && echo -e "${msg}"
    [[ ( $SILENT -eq 0 ) && ( $notice -eq 2 ) ]] && echo -e "\e[1;31m${msg}\e[0m"
    echo "$(date +"%FT%H:%M:%S"): $$ : $msg" >> $LOG
}

print_e(){
    msg_e=$1
    print "$msg_e" 2
    print "Installation logfile - $LOG" 1
    exit 1
}

disable_selinux(){
    sestatus_cmd=$(which sestatus 2>/dev/null)
    [[ -z $sestatus_cmd ]] && return 0

    sestatus=$($sestatus_cmd | awk -F':' '/SELinux status:/{print $2}' | sed -e "s/\s\+//g")
    seconfigs="/etc/selinux/config /etc/sysconfig/selinux"
    if [[ $sestatus != "disabled" ]]; then
        print "You must disable SElinux before installing the Bitrix Environment." 1
        print "You need to reboot the server to disable SELinux"
        read -r -p "Do you want disable SELinux?(Y|n)" DISABLE
        [[ -z $DISABLE ]] && DISABLE=y
        [[ $(echo $DISABLE | grep -wci "y") -eq 0 ]] && print_e "Exit."
        for seconfig in $seconfigs; do
            [[ -f $seconfig ]] && \
                sed -i "s/SELINUX=\(enforcing\|permissive\)/SELINUX=disabled/" $seconfig && \
                print "Change SELinux state to disabled in $seconfig" 1
        done
        print "Please reboot the system! (cmd: reboot)" 1
        exit
    fi
}

# EPEL
configure_epel(){

    # testing rpm package
    EPEL=$(rpm -qa | grep -c 'epel-release')
    if [[ $EPEL -gt 0 ]]; then
        print "EPEL repository is already configured on the server." 1
        return 0
    fi
 
    # links
    print "Getting configuration EPEL repository. Please wait." 1
    if [[ $VER -eq 6 ]]; then
        LINK="https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm"
        GPGK="https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6"
    else
        LINK="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
        GPGK="https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7"
    fi

    # configure repository
    rpm --import "$GPGK" >>$LOG 2>&1 || \
        print_e "An error occurred during importing the EPEL GPG key: $GPGK"
    rpm -Uvh "$LINK" >>$LOG 2>&1 || \
        print_e "An error occurred during installation the EPEL rpm-package: $LINK"

    # exclude ansible1.9
    echo "exclude=ansible1.9" >> /etc/yum.conf 
    
    # install packages
    yum clean all >/dev/null 2>&1 
    yum install -y yum-fastestmirror >/dev/null 2>&1

    print "Configuration EPEL repository is completed." 1
}

pre_php(){
    php56_conf=/etc/yum.repos.d/remi.repo
    php70_conf=/etc/yum.repos.d/remi-php70.repo

    print "Enable php70 repository"
    sed -i -e '/\[remi-php70\]/,/^\[/s/enabled=0/enabled=1/' $php70_conf

    print "Disable php56 repository"
    sed -i -e '/\[remi-php56\]/,/^\[/s/enabled=1/enabled=0/' $php56_conf

    is_xhprof=$(rpm -qa | grep -c php-pecl-xhprof)
    if [[ $is_xhprof -gt 0 ]]; then
        yum -y remove php-pecl-xhprof
    fi
}

# REMI; php and mysql packages
configure_remi(){
    # testing rpm package
    EPEL=$(rpm -qa | grep -c 'remi-release')
    if [[ $EPEL -gt 0 ]]; then
        print "REMI repository is already configured on the server." 1
        return 0
    fi
 
    # links
    print "Getting configuration REMI repository. Please wait." 1
    GPGK="http://rpms.famillecollet.com/RPM-GPG-KEY-remi"
    if [[ $VER -eq 6 ]]; then
        LINK="http://rpms.famillecollet.com/enterprise/remi-release-6.rpm"
    else
        LINK="http://rpms.famillecollet.com/enterprise/remi-release-7.rpm"
    fi

    # configure repository
    rpm --import "$GPGK" >>$LOG 2>&1 || \
        print_e "An error occurred during importing the REMI GPG key: $GPGK"
    rpm -Uvh "$LINK" >>$LOG 2>&1 || \
        print_e "An error occurred during installation the REMI rpm-package: $LINK"
    
    
    # configure php 5.6
    sed -i -e '/\[remi\]/,/^\[/s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo
    sed -i -e '/\[remi-php56\]/,/^\[/s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo

    print "Configuration REMI repository is completed." 1
}


configure_mariadb(){
    # testing rpm package
    REPOTEST=$(yum repolist | grep -c 'mariadb')
    if [[ $REPOTEST -gt 0 ]]; then
        print "MariaDB repository is already configured on the server." 1
        return 0
    fi

    if [[ $IS_CENTOS7 -gt 0 ]]; then
        tee /etc/yum.repos.d/mariadb.repo << EOF
# MariaDB 5.5 CentOS repository list - created 2016-07-14 08:15 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/5.5/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
        print "Configuration MariaDB repository is completed." 1
    else
        print "Configuration MariaDB repository is skipped." 1
    fi
}


# Bitrix; bitrix-env, bx-nginx
configure_bitrix(){
    # testing bitrix repository
    EPEL=$(yum repolist enabled | grep ^bitrix -c)
    if [[ $EPEL -gt 0 ]]; then
        print "Bitrix repository is already configured on the server." 1
        return 0
    fi

    # configure testing repository
    REPO=yum
    [[ $TEST_REPOSITORY -gt 0  ]] && REPO=yum-testing
 
    # get GPG key
    print "Getting configuration Bitrix repository. Please wait." 1
    GPGK="http://repos.1c-bitrix.ru/yum/RPM-GPG-KEY-BitrixEnv"
    rpm --import "$GPGK" >>$LOG 2>&1 || \
        print_e "An error occurred during importing the Bitrix GPG key: $GPGK"

    # create yum config file
    REPOF=/etc/yum.repos.d/bitrix.repo
    echo "[bitrix]" > $REPOF
    echo "name=\$OS \$releasever - \$basearch" >> $REPOF
    echo "failovermethod=priority" >> $REPOF
    echo "baseurl=http://repos.1c-bitrix.ru/$REPO/el/$VER/\$basearch" >> $REPOF
    echo "enabled=1" >> $REPOF
    echo "gpgcheck=1" >> $REPOF
    echo "gpgkey=$GPGK" >> $REPOF

    print "Configuration Bitrix repository is completed." 1
}

yum_update(){
	print "Update system. Please wait." 1
	yum -y update >>$LOG 2>&1 || \
        print_e "An error occurred during the update the system."
}

# copy-paste from mysql_secure_installation; you can find explanation in that script
basic_single_escape () {
    echo "$1" | sed 's/\(['"'"'\]\)/\\\1/g'
}

# generate random password
randpw(){
    local len="${1:-20}"
    if [[ $DEBUG -eq 0 ]]; then
        </dev/urandom tr -dc '?!@&\-_+@%\(\)\{\}\[\]=0-9a-zA-Z' | head -c20; echo ""
    else
        </dev/urandom tr -dc '?!@&\-_+@%\(\)\{\}\[\]=' | head -c20; echo ""
    fi

}

# generate client mysql config
my_config(){
    local cfg="${1:-$MYSQL_CNF}"
    echo "# mysql bvat config file" > $cfg
    echo "[client]" >> $cfg
    echo "user=root" >> $cfg
    local esc_pass=$(basic_single_escape "$MYSQL_ROOTPW")
    echo "password='$esc_pass'" >> $cfg
    echo "socket=/var/lib/mysqld/mysqld.sock" >> $cfg
}

# run query
my_query(){
    local query="${1}"
    local cfg="${2:-$MYSQL_CNF}"
    [[ -z $query ]] && return 1

    local tmp_f=$(mktemp /tmp/XXXXX_command)
    echo "$query" > $tmp_f
    mysql --defaults-file=$cfg < $tmp_f >> $LOG 2>&1
    mysql_rtn=$?

    rm -f $tmp_f
    return $mysql_rtn
}

# query and result
my_select(){
    local query="${1}"
    local cfg="${2:-$MYSQL_CNF}"
    [[ -z $query ]] && return 1

    local tmp_f=$(mktemp /tmp/XXXXX_command)
    echo "$query" > $tmp_f
    mysql --defaults-file=$cfg < $tmp_f
    mysql_rtn=$?

    rm -f $tmp_f
    return $mysql_rtn
}

my_additional_security(){
    # delete anonymous users
    my_query "DELETE FROM mysql.user WHERE User='';"
    [[ $? -eq 0 ]] && \
        print "Remove anonymous users in mysql service"

    # remove remote root
    my_query "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    [[ $? -eq 0 ]] && \
        print "Disable remote root access in mysql service"

    # remove test database
    my_query "DROP DATABASE test;"
    [[ $? -eq 0 ]] && \
        print "Remove DB test"

    my_query "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    [[ $? -eq 0 ]] && \
        print "Remove all privileges on test DBs"


    # flush privileges
    my_query "FLUSH PRIVILEGES;"
    [[ $? -eq 0 ]] && \
        print "Reload mysql privileges"

}

my_generate_sitepw(){
    local site_dbcon="$DEFAULT_SITE/bitrix/php_interface/dbconn.php"
    local site_settings="$DEFAULT_SITE/bitrix/.settings.php"
    local site_db=$(cat $site_dbcon | \
        grep -v '^#\|^$\|^;' | grep -w DBName | \
        awk -F'=' '{print $2}' | sed -e 's/"//g;s/;//;s/\s\+//')

    [[ -f $site_dbcon && -f $site_settings ]]  || return 1

    # test root login in config files
    is_root_dbcon=$(cat $site_dbcon | grep -v '\(^$\|^;\|^#\)' | \
        grep -w "DBLogin" | grep -wc root)
    is_root_settings=$(cat $site_settings | grep -v '\(^$\|^;\|^#\)' | \
        grep -w "login" | grep -wc root)
    [[ ( $is_root_dbcon -eq 0 ) && ( $is_root_settings -eq 0 ) ]] && return 1

    # create db, if not exist
    [[ ! -d "/var/lib/mysql/$site_db" ]] && \
        my_query "CREATE DATABASE $site_db"

    # create user for site
    user_id=0
    user_base=bitrix
    user_select=
    while [[ -z $user_select ]]; do
        print "Testing user=${user_base}${user_id}"
        user_tmp=$(mktemp /tmp/XXXXXX_user)
        is_user=0
        my_select "SELECT User FROM mysql.user WHERE User='${user_base}${user_id}'" > $user_tmp 2>&1
        if [[ $? -gt 0 ]]; then
            rm -f $user_tmp
            print_e "Cannot test existence mysql user"
        else
            is_user=$(cat $user_tmp | grep -wc "${user_base}${user_id}")
        fi

        [[ $is_user -eq 0 ]] && \
            user_select="${user_base}${user_id}"
        user_id=$(( $user_id + 1 ))
    done
    BITRIX_PW=$(randpw)
    print "Generate user name=$user_select for default site"

    # create user and its grants
    esc_pass=$(basic_single_escape "$BITRIX_PW")
    [[ $DEBUG -gt 0 ]] && echo "name=$user_select password=$BITRIX_PW esc_password=$esc_pass"

    my_query "CREATE USER '$user_select'@'localhost' IDENTIFIED BY '$esc_pass';"
    if [[ $? -gt 0 ]]; then
        print_e "Cannot create user=$user_select"
    else
        print "Create user=$user_select"
    fi

    my_query "GRANT ALL PRIVILEGES ON $site_db.* TO '$user_select'@'localhost';"
    if [[ $? -gt 0 ]]; then
        print_e "Cannot grant access rights to user=$user_select"
    else
        print "Grant access rights to user=$user_select"
    fi



    # replace option in the config files
    # because special chars we give up on sed tool
    DBPassword_line=$(grep -n "^\s*\$DBPassword" $site_dbcon | awk -F':' '{print $1}')
    [[ -z $DBPassword_line ]] && \
        print "Cannot find DBPassword option in $site_dbcon" && \
        return 1

    {
        head -n $(( $DBPassword_line-1 )) $site_dbcon
        echo "\$DBPassword = '$esc_pass';" 
        tail -n +$(( $DBPassword_line+1 )) $site_dbcon
    } | \
        sed -e "s/\$DBLogin.\+/\$DBLogin \= \'$user_select\'\;/g" \
        > $site_dbcon.tmp
    mv $site_dbcon.tmp $site_dbcon
    chown bitrix:bitrix $site_dbcon
    chmod 640 $site_dbcon
    print "Update $site_dbcon"

    password_line=$(grep -n "^\s*'password'" $site_settings | awk -F':' '{print $1}')
    [[ -z $password_line ]] && \
        print "Cannot find password option in $site_settings" && \
        return 1

    {
        head -n $(( $password_line-1 )) $site_settings
        echo "        'password' => '$esc_pass'," 
        tail -n +$(( $password_line+1 )) $site_settings
    } | \
        sed -e "s/'login' => '.\+',/'login' => '$user_select',/g" \
        > $site_settings.tmp
    mv $site_settings.tmp $site_settings
    chown bitrix:bitrix $site_settings
    chmod 640 $site_settings
    print "Update $site_settings"

}


config_root_pw(){
    # test root has empty password
    MYSQL_ROOTPW=''
    local my_temp=$MYSQL_CNF.temp
    my_config "$my_temp"
    my_query "status;" "$my_temp"
    [[ $? -gt 0 ]] && return 0
    print "Test empty root password - pass"
	
    # ask user
    print "MySQL root password is not set"
    read -r -p "Do you want to set a password for root user in MySQL service?(Y|n): " user_answer
    [[ $( echo "$user_answer" | grep -wci "\(No\|n\)" ) -gt 0 ]] && return 1

    MYSQL_ROOTPW=
    limit=5
    until [[ -n "$MYSQL_ROOTPW" ]]; do
        password_check=

        if [[ $limit -eq 0 ]]; then
            print "Have exhausted maximum number of retries for password set. Exit."
            return 1
        fi
        limit=$(( $limit - 1 ))

        read -s -r -p "Enter root password: " MYSQL_ROOTPW
        echo
        read -s -r -p "Re-enter root password: " password_check

        if [[ ( -n $MYSQL_ROOTPW ) && ( "$MYSQL_ROOTPW" = "$password_check" ) ]]; then
            :
        else
            [[ "$MYSQL_ROOTPW" != "$password_check" ]] && \
                print "Sorry, passwords do not match! Please try again."
            
            [[ -z "$MYSQL_ROOTPW" ]] && \
                print "Sorry, password can't be empty."
            MYSQL_ROOTPW=
        fi
    done
    
    # update password
    local esc_pass=$(basic_single_escape "$MYSQL_ROOTPW")
    my_query \
        "UPDATE mysql.user SET Password=PASSWORD('$esc_pass') WHERE User='root'; FLUSH PRIVILEGES;" \
        "$my_temp"
    if [[ $? -gt 0 ]]; then
        rm -f $my_temp
        print_e "An error occurred while updating root password"
    fi
    print "Setting root password is successful"

    # create config
    my_config
    print "Create mysql client config file=$MYSQL_CNF"

    # configure additinal options
    my_additional_security
    print "Main configuration of mysql security is complete"

    # default site configuration
   	my_generate_sitepw 
}


# testing effective UID
[[ $EUID -ne 0 ]] && \
    print_e "This script must be run as root or it will fail" 

# testing OS name
[[ $OS != "CentOS" ]] && \
    print_e "This script is designed for use in OS CentOS Linux; Current OS=$OS"

# Notification
if [[ $SILENT -eq 0 ]]; then
    print "====================================================================" 2
    print "Bitrix Environment for Linux installation script." 2
    print "Yes will be assumed to answers, and will be defaulted." 2
    print "'n' or 'no' will result in a No answer, anything else will be a yes." 2
    print "This script MUST be run as root or it will fail" 2
    print "====================================================================" 2
fi

# testing Centos vesrion
IS_CENTOS7=$(grep -c 'CentOS Linux release' $RELEASE_FILE)
IS_X86_64=$(uname -p | grep -wc 'x86_64')
if [[ $IS_CENTOS7 -gt 0 ]]; then
    VER=$(awk '{print $4}' $RELEASE_FILE | awk -F'.' '{print $1}')
else
    VER=$(awk '{print $3}' $RELEASE_FILE | awk -F'.' '{print $1}')
fi
[[ ( $VER -eq 6 ) || ( $VER -eq 7 ) ]] || \
    print_e "The script does not support the Centos ${VER}."

disable_selinux

# update all packages
yum_update

# configure repositories
configure_epel
configure_remi
pre_php
configure_mariadb
configure_bitrix

# update all packages (EPEL and REMI packages)
yum_update

# install specific php packages (there is no dependencies in RPM)
print "Install php packages. Please wait." 1
yum -y install php php-mysql \
    php-pecl-apcu php-pecl-zendopcache >>$LOG 2>&1 || \
    print_e "An error occurred during installation of php-packages"

print "Install bitrix-env package. Please wait." 1
yum -y install bitrix-env >>$LOG 2>&1 || \
    print_e "An error occurred during installation of bitrix-env package"

# mysql root password
config_root_pw

print "Bitrix Environment installation is completed." 1
rm -f $LOG
