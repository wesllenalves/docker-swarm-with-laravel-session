FROM php:8.2.1-apache

USER root

WORKDIR /var/www/html

#corrige a versao do apache para a ultima: adiciona o repo e depois install.
RUN echo 'deb http://ftp.br.debian.org/debian sid main' >> /etc/apt/sources.list
RUN apt-get clean
RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -qq -y zip unzip vim curl wget < /dev/null > /dev/null
RUN DEBIAN_FRONTEND=noninteractive apt-get install -qq -y apache2 < /dev/null > /dev/null

RUN DEBIAN_FRONTEND=noninteractive apt-get install -qq -y \
        libpng-dev \
        libpq-dev \
        zlib1g-dev \
        libxml2-dev \
        libzip-dev \
        libonig-dev \
        iputils-ping < /dev/null > /dev/null

RUN docker-php-ext-configure gd > /dev/null \
    && docker-php-ext-install -j$(nproc) gd > /dev/null \
    && docker-php-ext-install pdo > /dev/null \
    && docker-php-ext-install pdo_pgsql > /dev/null \
    && docker-php-ext-install pdo_mysql > /dev/null \
    && docker-php-ext-install pgsql > /dev/null \
    && docker-php-ext-install mbstring > /dev/null \
    && docker-php-ext-install dom > /dev/null \
    && docker-php-ext-install xml > /dev/null \
    && docker-php-ext-install zip > /dev/null \
    && docker-php-ext-install opcache > /dev/null \
    && docker-php-source delete > /dev/null

ENV TZ=America/Sao_Paulo
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# RUN rm -f /etc/apache2/sites-enabled/000-default.conf
# ADD apache-local.conf /etc/apache2/sites-available/000-default.conf

# Remove cache and logs if some and fixes permissions
RUN rm -rf /var/cache/* && rm -rf /var/logs/* && rm -rf /var/sessions/*
RUN rm -f /var/run/apache2/apache2.pid

# 2. apache configs + document root
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# 3. mod_rewrite for URL rewrite and mod_headers for .htaccess extra headers like Access-Control-Allow-Origin-
RUN a2enmod rewrite headers

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

ADD . /var/www/html
RUN rm -f composer.lock
RUN rm -f storage/logs/laravel.log
RUN rm -rf vendor
RUN rm -rf public/coverage
RUN rm -rf bootstrap/cache/*
RUN rm -rf storage/framework/cache/data/*

RUN composer install --prefer-dist -o -q -n
RUN php artisan key:generate


RUN chmod 777 -R /var/www/html
#RUN php artisan l5-swagger:generate

RUN chmod a+rw /var/www/html/storage -R
RUN chmod a+r /var/run/apache2 -R
RUN chmod a+rw bootstrap/cache -R

RUN a2enmod headers 
RUN a2enmod rewrite

RUN php artisan route:clear
RUN php artisan config:cache
RUN php artisan cache:clear

#RUN chown www-data:www-data -R bootstrap
#RUN chown www-data:www-data -R storage

RUN echo 'opcache.enable=1' >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
RUN echo 'opcache.enable_cli=1' >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
RUN echo 'opcache.jit_buffer_size=256M' >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
RUN echo 'opcache.jit=1255' >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

#ENTRYPOINT yes | exec apache2-foreground

ENTRYPOINT yes | php artisan migrate && php artisan queue:restart && exec apache2-foreground