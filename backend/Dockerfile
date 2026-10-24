# Production image for the Laravel API (Render web service; docs/deploy/render.md).
# Apache + mod_php on the PORT Render provides. No database migrations run here or at start-up.

# Vite assets for the welcome page (/), as the previous host built them.
FROM node:22-alpine AS assets
WORKDIR /app
COPY package.json vite.config.js ./
COPY resources ./resources
RUN npm install --no-audit --no-fund --loglevel=error && npm run build

FROM php:8.2-apache

# pdo_mysql: MySQL. bcmath: money arithmetic. intl: parity with the previous runtime. opcache: speed.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libicu-dev unzip \
    && docker-php-ext-install -j"$(nproc)" pdo_mysql bcmath intl opcache \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --no-progress --prefer-dist --no-scripts --no-autoloader

COPY . .
COPY --from=assets /app/public/build ./public/build
RUN mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && composer dump-autoload --no-dev --optimize \
    && php artisan package:discover --ansi \
    && chown -R www-data:www-data storage bootstrap/cache

COPY docker/apache-vhost.conf /etc/apache2/sites-available/000-default.conf
COPY docker/php.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/entrypoint.sh /usr/local/bin/app-entrypoint
RUN chmod +x /usr/local/bin/app-entrypoint

EXPOSE 10000
CMD ["app-entrypoint"]
