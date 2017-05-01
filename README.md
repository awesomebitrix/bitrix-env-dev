### Введение

Данная разработка пригодится тем, кому нужно быстро поднять у себя локально песочницу для веб-проекта на 1С-Битрикс.
И не простую песочницу, а со всеми инструментами для быстрой и удобной работы над проектом.

А именно:

* отладчик xdebug
* встроенный mysql-сервер, принимающий подключения извне
* доступ по SSH
* полезный серверный софт, вроде _htop_, _nano_, _mc_ и так далее

Образ имеет и другие вкусности:
* можно развернуть BitrixVM как на современном PHP7, так и на старом-добром PHP5.
* поддерживается многосайтовость; для этого нужно будет создать по контейнеру на каждый сайт (см. подробности ниже)

### Подготовка

Для начала вам нужно иметь на локальной Linux-машине:

* данный репозиторий
* дамп базы данных продакшна (.sql файл)
* все файлы битрикс-проекта, включая его ядро


Допустим, что дамп базы вы уже скачали и он лежит в папке:
 ```bash
    ~/bitrix-project-source/database-dump.sql
 ```
А файлы проекта тоже имеете при себе и они располагаются по адресу:
```bash
    ~/bitrix-project-source/files/
```

Можно идти дальше.

Прежде чем мы приступим, я расскажу о том, что будет происходить на этапе сборки:

* установим правильную временную зону
* запустим официальный скрипт _bitrix-env.sh_, который установит весь LAMP-стек и правильно его настроит
* добавим оптимальный конфиг для xdebug
* установим тот самый полезный софт
* зададим свои пароли для системных пользователей root и bitrix (для доступа по ssh)
* зададим свой пароль для пользователя bitrix во встроенном mysql-сервере (если вы будете его использовать)
* разрешим подключение к нашей базе данных извне; это нужно для импорта дампа базы проекта (по-умолчанию, mysql-сервер разрешает подключаться к себе только через _localhost_)

А теперь о запуске контейнеров из нашего свеженького образа.

Мы будем запускать контейнеры через .sh скрипты; это позволит нам быстрее и проще запускать и перезапускать контейнер.

### Доступы к контейнеру по-умолчанию

Если вы не укажете явно доступы к ssh и mysql как аргументы к _docker run_, к контейнеру будут применены стандартные значения, а именно:

SSH:
* root / 4EyahtMj
* bitrix / XW7ur3TB

MySQL:
* bitrix / JX6kbx8b


### Сборка образа

Клонируем себе на Linux-машину исходники для сборки образа:

```bash
    $ mkdir ~/Docker
    $ cd ~/Docker
    $ git clone git@github.com:hybr1dmax/bitrix-env-dev.git
    $ cd bitrix-env-dev
```

Начинаем сборку образа по докерфайлу:

```bash
    $ docker build -t hybr1dmax/bitrix-env-dev . 
```
По-умолчанию, BitrixVM будет идти комплекте с php7.
Если вам требуется php5, укажите специальный параметр **_IS_LEGACY_PHP=1_**

```bash
    $ docker build --build-arg IS_LEGACY_PHP=1 -t hybr1dmax/bitrix-env-dev .
```

Сборка образа может занять несколько минут, всё зависит от вашей скорости соединения.

Давайте посмотрим, что у нас вышло:
```bash
    $ docker images
    REPOSITORY                 TAG                 IMAGE ID            CREATED             SIZE
    hybr1dmax/bitrix-env-dev   latest              2bdc7287012f        1 minute ago        1.2GB
    centos                     6.6                 d03626170061        8 months ago        203MB
```

Образ на месте, пора создавать контейнер от получившегося образа.

### Подготовка запуска

Как я уже сказал, команды запуска контейнера мы обернем в .sh-скрипты.
Для этого создаем папку containers:
```bash
    $ mkdir containers
    $ cd containers/
```

Наш контейнер будем называть **sandbox.local**, айпишник ему выставим **10.10.0.2**

Создаем для него скрипт запуска:
```bash
    $ touch sandbox_run.sh
```

Вставляем в него следующее содержимое:
```bash
    #!/bin/sh
    
    docker stop sandbox.local;
    docker rm sandbox.local;
    
    docker run -id \
    -h sandbox.local \
    --name sandbox.local \
    --net=my-docker-network --ip=10.10.0.2 \
    -e BITRIX_SSH_PASS="bitrix_passphrase" \
    -e ROOT_SSH_PASS="root_passphrase" \
    -e BITRIX_DB_PASS="database_user_passphrase" \
    -e DB_NAME="database_name" \
    -v ~/bitrix-project-source/files:/home/bitrix/www \
    hybr1dmax/bitrix-env-dev;
```

#### Подробнее о скрипте запуска

_docker run_ и _docker rm_ уничтожают контейнер, если мы его уже запускали. 

Сам _docker run_ содержит в себе множество аргументов; давайте разберемся в них:

* **_-id_** запускаем контейнер в интерактивном режиме и на фоне
* **_-h sandbox.local_** и **_--name sandbox.local_** красиво обзываем контейнер + выставляем внутреннее доменное имя
* **_--net=my-docker-network --ip=10.10.0.2_** подключаем контейнер к нашей кастомной докер-сети и выставляем контейнеру айпишник 10.10.0.2
* **_-e BITRIX_SSH_PASS="bitrix_passphrase"_** переопределяем стандартный пароль к системному юзеру bitrix
* **_-e ROOT_SSH_PASS="root_passphrase"_** переопределяем стандартный пароль к системному юзеру root
* **_-e BITRIX_DB_PASS="database_user_passphrase"_** переопределяем стандартный пароль к юзеру bitrix встроенного mysql-сервера
* **_-e DB_NAME="database_name"_** если указано, и если не указан параметр _NOMYSQL=1_, то создаем базу данных с указанным именем
* **_-v ~/bitrix-project-source/files:/home/bitrix/www_** монтируем папку с нашим проектом внутрь контейнера

Также доступны другие опции:
* **_-e NOMYSQL=1_** если определен этот параметр, то контейнер больше работает со встроенным сервером MySQL; это для тех, кто хочет держать базу в другом контейнере (отличный вариант, кстати)
* **_-e CYRILLIC_MODE=1_** если ваш проект в кодировке _windows-1251_, то эта опция позволит перенастроить mbstring.func_overload и mbstring.internal_encoding в настройках php
* **_DB_ADDITIONAL_PARAMS="character set cp1251"_** значение этого параметра добавится в конец запроса _CREATE DATABASE_, при создании контейнера.


#### Многосайтовость

Раздел еще в разработке...

#### DNS

Чтобы с нашей рабочей машины обращаться к нашему контейнеру через доменное имя, а не через айпишник, добавим в свой _/etc/hosts_ запись о _sandbox.local_:
```bash
    $ sudo echo "sandbox.local 10.10.0.2" >> /etc/hosts
```

#### Импорт базы

Вливаем наш дамп базы данных:

```bash
    $ mysql -h sandbox.local -u bitrix -p database_name < ~/bitrix-project-source/database-dump.sql
```

Не забываем поправить настройки базы данных в _dbconn.php_ и _.settings.php_, а именно:
* логин пользователя (_bitrix_)
* пароль пользователя
* хостнейм сервера базы данных (_sandbox.local_ или _localhost_)


### Запуск

```bash
    $ bash ./sandbox_run.sh
```

После этого можно подключаться к нашему контейнеру через _sandbox.local_