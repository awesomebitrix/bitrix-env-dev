# Подготовка

Данный образ позволяет быстро развернуть копию веб-проекта на системе 1С-Битрикс.
Для старта нам понадобится:

* дамп базы целевого веб-проекта
* все файлы веб-проекта, включая ядро битрикс /bitrix/
* создать кастомную подсеть в docker, чтобы самим решать по какому ip будет доступна наша песочницаю

Допустим, что:

* дамп базы вы уже скачали и он лежит в папке:
 ```bash
 ~/bitrix-project-source/database-dump.sql
 ```
* файлы проекта тоже имеете при себе и они располагаются по адресу:
```bash
~/bitrix-project-source/files/
```
Создаем подсеть:
```bash
docker network create --subnet=10.10.0.0/16 my-docker-network
```

## Сборка

Клонируем себе на Linux-машину исходники для сборки образа:

```bash
   mkdir ~/Docker
   cd ~/Docker
   git clone git@github.com:hybr1dmax/bitrix-env-dev.git
   cd bitrix-env-dev
```

Начинаем сборку образа по докерфайлу:

```bash
   docker build -t hybr1dmax/bitrix-env-dev . 
```
По-умолчанию, BitrixVM будет идти комплекте с php7.
Если вам требуется php5, укажите специальный параметр **_IS_LEGACY_PHP=1_**

```bash
   docker build --build-arg IS_LEGACY_PHP=1 -t hybr1dmax/bitrix-env-dev .
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

## Запуск

Создаем папку containers, в которую будем помещать bash-скрипты для более удобного запуска и перезапуска контейнеров:
```bash
   mkdir containers
   cd containers/
   touch sandbox_run.sh
```


Создаем скрипт для нашего проекта:
```bash
   touch sandbox_run.sh
```

Вставляем в него следующее содержимое:
```bash
   #!/bin/sh
   
   docker stop sandbox.local;
   docker rm sandbox.local;
   
   docker run -itd \
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
Как видите, мы будем подключать наш контейнер к подсети _my-docker-network_ и выставлять ему IP _10.10.0.2_. Это нужно для того, чтобы обращаться к нашему контейнеру по доменному имени, а не по IP.


Добавляем в свой /etc/hosts запись о новом контейнере:
```bash
   $ sudo echo "sandbox.local 10.10.0.2" >> /etc/hosts
```

А теперь самое интересное - запуск:
```bash
    bash ./sandbox_run.sh
```

Продолжение следует...