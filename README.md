# Введение

Docker-образ, созданный для быстрого разворачивания Битрикс-окружения, со всеми нужными инструментами для разработки и администрирования.

В комплекте идут:

* настроенный php-отладчик XDebug
* ssh-сервер
* разные полезные утилиты: htop, nano, mc, zip/unzip, screen и так далее


Изначально проект был нацелен на разработчиков, которые хотят развернуть у себя песочницу на основе реального проекта.

Но постепенно я расширил функционал: теперь образ вполне пригоден и для продакшна.

## Организация работы

Здесь я кратко изложу суть работы контейнеров и правильного взаимодействия с ними.

### Файлы проекта
Файлы проекта будут обязаны иметь обладателя bitrix:bitrix, поэтому напрямую править их будет глупостью.

Есть идея получше: обмен файлами между IDE и контейнером обеспечит ssh/sftp от пользователя bitrix.

### Сеть и DNS

Мы не будем пробрасывать какие-либо порты контейнера на `localhost` (как любят советовать многие образ-мейкеры), а будем обращаться к контейнеру напрямую через внутренний IP.

В этом нам поможет кастомная докер-сеть и наш `/etc/hosts`.

### База данных

Хоть веб-окружение Битрикс и предоставляет для работы mysql-сервер, нам удобнее использовать свой и в отдельном контейнере.

Почему? Стоит перезапустить контейнер с Битрикс-окружением и базой внутри через `docker run` и вы потеряете данные в базе.
Придется их заливать заново. Неприятно.

Еще мы вынесем директорию с данными mysql в хост-систему, чтоб они не терялись между перезапусками mysql-контейнера.

В работу возьмём официальный образ mysql:

https://hub.docker.com/_/mysql/

### Управление контейнерами

Скорее всего, в процессе работы, вам нужно будет перезапускать контейнер с нуля. И не один раз.

Постоянно выполнять команды `docker run`, `docker stop`, `docker rm` быстро надоест, поэтому мы вынесем этим команды в отдельные .sh-скрипты.

# Сборка и подготовка образов

### Сборка образа Bitrix

Что ж, я думаю вы насытились теоретической информацией и хотите перейти к практике.

На данный момент образ собирается ручками, через `docker build`.

В скором времени я добавлю образ в главный хаб Docker, откуда можно будет достать готовый образ.

Итак, клонируем себе на машину исходники для сборки образа:

```bash
    $ mkdir ~/Docker
    $ cd ~/Docker
    $ git clone git@github.com:hybr1dmax/bitrix-env-dev.git
    $ cd bitrix-env-dev
```

Начинаем сборку образа через Dockerfile:

```bash
    $ docker build -t hybr1dmax/bitrix-env-dev . 
```
По-умолчанию, _1С Битрикс: Веб-окружение_ будет идти комплекте с php7.
Если вам требуется php5, укажите специальный параметр `IS_LEGACY_PHP=1`

```bash
    $ docker build --build-arg IS_LEGACY_PHP=1 -t hybr1dmax/bitrix-env-dev:php5 .
```

После этого образ для сайта готов.

### Подготовка образа MySQL

Собирать здесь ничего не будем, ибо есть прекрасный официальный образ `mysql` в хабе:

```bash
    $ docker pull mysql

```

# Подготовка контейнеров

### Скрипт запуска для Bitrix-контейнера


Наш контейнер будем называть `project.local`, айпишник ему выставим `10.10.0.3`

Создаем для него скрипт запуска:
```bash
    $ mkdir containers
    $ touch containers/project_run.sh
```

Вставляем в него следующее содержимое:
```bash
    #!/bin/sh
    
    docker stop project.local;
    docker rm project.local;
    
    docker run -id \
    -h project.local \
    --name project.local \
    --net=my-docker-network --ip=10.10.0.3 \
    -e NOMYSQL=1 \
    -e BITRIX_SSH_PASS="bitrix_passphrase" \
    -e ROOT_SSH_PASS="root_passphrase" \
    -v ~/bitrix-project/files:/home/bitrix/www \
    hybr1dmax/bitrix-env-dev;
```

#### Подробнее о параметрах

`docker run` и `docker rm` уничтожают контейнер, если мы его уже запускали. 

Сам `docker run` содержит в себе множество аргументов; давайте разберемся в них:

* `-id` - запускаем контейнер как фоновый процесс
* `-h project.local`, `--name project.local` - красиво обзываем контейнер + выставляем внутренний хостнейм
* `--net=my-docker-network --ip=10.10.0.3` - подключаем контейнер к нашей кастомной докер-сети и выставляем контейнеру айпишник
* `-e NOMYSQL=1` - если определен этот параметр, то в контейнере не будет конфигурироваться и запускаться встроенный mysql
* `-e BITRIX_SSH_PASS="bitrix_passphrase"` - определяем пароль для пользователя `bitrix`
* `-e ROOT_SSH_PASS="root_passphrase"` - определяем пароль для пользователя `root`
* `-v ~/bitrix-project/files:/home/bitrix/www` - монтируем из хост-системы папку с нашим проектом внутрь контейнера

Также доступны другие опции:

* `-e XDEBUG=1` активация отладчика XDebug
* `-e MULTISITE_ID=2` параметр, для корректной работы многосайтовости (см. раздел `Многосайтовость`).
* `-e CYRILLIC_MODE=1` если ваш проект в кодировке `windows-1251`, то эта опция позволит указать соответствующие `mbstring.func_overload` и `mbstring.internal_encoding` в конфигах php


### Скрипт запуска для MySQL-контейнера

Создаем для него скрипт запуска:
```bash
    $ touch containers/mysql_run.sh
```

Вставляем в него следующее содержимое:
```bash
    #!/bin/sh
    
    docker stop mysql.local;
    docker rm mysql.local;
    
    docker run -id \
    -h mysql.local \
    --name mysql.local \
    --net=my-docker-network --ip=10.10.0.2 \
    -e MYSQL_ROOT_PASSWORD='db-root-password' \
    -e MYSQL_USER='bitrix' \
    -e MYSQL_PASSWORD='db-bitrix-password' \
    -v /path/to/mysql-lib-dir:/var/lib/mysql \
    -v /etc/localtime:/etc/localtime:ro \
    mysql:5.5;
```

Вместо `/path/to/mysql-lib-dir` укажите путь до пустой папки, которую mysql наполнит своими данными и будет их использовать между перезапусками контейнера.

### DNS

Чтобы с нашей рабочей машины обращаться к нашему контейнеру через доменное имя, а не через айпишник, добавим в свой `/etc/hosts` запись о хостнейме `project.local`:
```bash
    $ su
    echo "10.10.0.2 project.local" >> /etc/hosts
```

Создадим свою docker-сеть:

```bash
    $ docker network create my-docker-network --subnet=10.10.0.0/16
```


### Доступы ssh

Если вы не укажете явно доступы к ssh, будут применены стандартные значения:

* `root` / `4EyahtMj`
* `bitrix` / `XW7ur3TB`


### Многосайтовость

Если вы хотите запустить проект с несколькими сайтами на одной лицензии, то укажите параметр для запуска `MULTISITE_ID`.

Допустимые значения - от 2 до бесконечности.

Примеры: 

* для сайта №2 укажите `MULTISITE_ID` равный 2; в настройках сайта поменяйте путь с `/home/bitrix/www` на `/home/bitrix/www2`
* для сайта №5 укажите `MULTISITE_ID` равный 5; в настройках сайта поменяйте путь с `/home/bitrix/www` на `/home/bitrix/www5`

Дальше остается решить вопрос с монтированием. Для неосновного сайта необходимо подключить ядро базового сайта.

И да, не забудьте примонтировать папки соседних сайтов рядом, чтобы сайты могли видеть файлы друг друга.


Сейчас будет наглядный пример параметров `MULTISITE_ID` и монтирования (связка сайтов №1 и №2).

Параметры сайта №2:
```bash
    docker run -id \
    -e MULTISITE_ID=2 \
    -v /path/to/project2:/home/bitrix/www2 \
    -v /path/to/project1/bitrix:/home/bitrix/www2/bitrix \
    -v /path/to/project1:/home/bitrix/www \
    hybr1dmax/bitrix-env-dev;
```
Тогда для сайта №1 опции следующие:
```bash
    docker run -id \
    -v /path/to/project1:/home/bitrix/www \
    -v /path/to/project2:/home/bitrix/www2 \
    hybr1dmax/bitrix-env-dev;
```

Всё просто.

А теперь объясню как это работает под капотом.

В настройках сайта мы прописываем путь в параметре `Путь к корневой папке веб-сервера для этого сайта`.

Это наиважнейший параметр для корректной работы многосайтовости. В нем хранится абсолютный путь до файлового корня сайта. 
И еще он должен быть **уникальным** по всему проекту. То есть нельзя для двух сайтов указать `/home/bitrix/www`.

Мы будем на 1 сайт запускать 1 контейнер, поэтому мы дадим Битриксу то, что он хочет: разные пути до проекта.

Возьмём пример сайтов №1 и №2.

В контейнере сайта №1 мы будем хранить файлы по старинке, в `/home/bitrix/www`.

В контейнер сайта №2 мы примонтируем файлы проекта в `/home/bitrix/www2`. 

С помощью `find` и `sed` мы заменим строку `/home/bitrix/www` на `/home/bitrix/www2` во всех конфигах второго контейнера.

Данный процесс уже автоматизирован в скрипте `run.sh`, который стартует вместе с контейнером.

Вот и всё.

# Запуск контейнеров

```bash
    $ bash containers/mysql_run.sh
    $ bash containers/project_run.sh
```

После этого можно подключаться к нашему проекту через доменное имя _project.local_, а к базе - через _mysql.local_

Дальше всё понятно:

* вливаем дамп базы в `mysql.local`
* меняем настройки базы `.settings.php` и `dbconn.php` в проекте
* заходим в админку и меняем урлы и доменные имена на `project.local` (это позволит правильно выставлять битриксовые куки (найти эти параметры можно в Главном модуле и настройках нужного сайта)

Теперь можно работать.

Настройки XDebug предельно стандартные.

Пример для `project.local`:

* порт `9000`
* хостнейм `project.local`
* папка на сервере `/home/bitrix/www`


Файлы проекта правим через _ssh/sftp_:

```bash
    $ ssh bitrix@project.local
```