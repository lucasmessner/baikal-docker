# Multi-stage build für Baikal
FROM alpine AS builder

ENV VERSION 0.13.0

ADD https://github.com/sabre-io/Baikal/releases/download/$VERSION/baikal-$VERSION.zip .
RUN apk add unzip && unzip -q baikal-$VERSION.zip
RUN mv /baikal /baikal-src

# Finales Docker-Image mit Nginx als Basis (wie im Original)
FROM nginx:latest

# Installation von Abhängigkeiten, PHP 8.3 und SQLite3
RUN curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    apt-get update && \
    apt-get install -y lsb-release && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
    apt-get remove -y lsb-release && \
    apt-get update && \
    apt-get install -y \
    php8.3-curl \
    php8.3-fpm \
    php8.3-mbstring \
    php8.3-mysql \
    php8.3-pgsql \
    php8.3-sqlite3 \
    php8.3-xml \
    sqlite3 \
    msmtp msmtp-mta && \
    rm -rf /var/lib/apt/lists/* && \
    sed -i 's/www-data/nginx/' /etc/php/8.3/fpm/pool.d/www.conf && \
    sed -i 's/^listen = .*/listen = \/var\/run\/php-fpm.sock/' /etc/php/8.3/fpm/pool.d/www.conf

# Baikal & Nginx Konfiguration kopieren
COPY files/docker-entrypoint.d/*.sh files/docker-entrypoint.d/*.php files/docker-entrypoint.d/nginx/ /docker-entrypoint.d/
COPY --from=builder --chown=nginx:nginx /baikal-src /var/www/baikal
COPY files/nginx.conf /etc/nginx/conf.d/default.conf

VOLUME /var/www/baikal/config
VOLUME /var/www/baikal/Specific
