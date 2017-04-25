# Песочница для разработчиков на BitrixVM

Docker-образ, внутри которого CentOS 6.6 + BitrixVM.

Добавлен конфиг XDebug, дополнительно установлены ssh, nano, mc.

Есть возможность развернуть несколько проектов в режиме родной многосайтовости.

## Сборка

Клонируем себе на Linux-машину репозиторий:


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
   docker build --build-arg IS_LEGACY_PHP=1 -t hybr1dmax/bitrix-env-dev:php5 .
```

Сборка образа может занять несколько минут, всё зависит от вашей скорости соединения.

## Запуск

Раздел в разработке....