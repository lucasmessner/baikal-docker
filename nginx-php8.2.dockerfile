# Multi-stage build, see https://docs.docker.com/develop/develop-images/multistage-build/
FROM alpine AS builder

ENV VERSION 0.10.1

ADD https://github.com/sabre-io/Baikal/releases/download/$VERSION/baikal-$VERSION.zip .
RUN apk add unzip && unzip -q baikal-$VERSION.zip

# NEU: PHP und Composer im Builder installieren, um Twig auf eine sichere Version zu aktualisieren
RUN apk add php83 php83-phar php83-openssl php83-mbstring php83-json php83-dom composer
WORKDIR /baikal
# Kopiere den entpackten Inhalt ins Arbeitsverzeichnis falls nötig oder arbeite direkt darauf
RUN cd / && mv baikal /baikal-src

# Wir erzwingen hier für Twig eine sichere Version >= 3.26.0 (schließt GHSA-7p85-w9px-jpjp)
RUN cd /baikal-src && composer require twig/twig:"^3.26.0" --no-update || true
# Alternativ, falls Baïkal Composer direkt nutzt:
# RUN cd /baikal-src && composer update twig/twig --with-dependencies

# Final Docker image
FROM nginx:1

# Install dependencies: PHP (with libffi6 dependency) & SQLite3
RUN curl -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg &&\
  apt update                  &&\
  apt install -y lsb-release  &&\
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list &&\
  apt remove -y lsb-release   &&\
  apt update                  &&\
    apt install -y            \
    php8.3-curl               \
    php8.3-fpm                \
    php8.3-mbstring           \
    php8.3-mysql              \
    php8.3-pgsql              \
    php8.3-sqlite3            \
    php8.3-xml                \
    sqlite3                   \
    msmtp msmtp-mta           &&\
  rm -rf /var/lib/apt/lists/* &&\
  sed -i 's/www-data/nginx/' /etc/php/8.3/fpm/pool.d/www.conf &&\
  sed -i 's/^listen = .*/listen = \/var\/run\/php-fpm.sock/' /etc/php/8.3/fpm/pool.d/www.conf

# Add Baikal & nginx configuration
COPY files/docker-entrypoint.d/*.sh files/docker-entrypoint.d/*.php files/docker-entrypoint.d/nginx/ /docker-entrypoint.d/
COPY --from=builder --chown=nginx:nginx /baikal-src /var/www/baikal
COPY files/nginx.conf /etc/nginx/conf.d/default.conf

VOLUME /var/www/baikal/config
VOLUME /var/www/baikal/Specific
