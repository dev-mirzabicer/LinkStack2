# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE=linkstackorg/linkstack:latest

FROM composer:2 AS composer_deps
WORKDIR /var/www/html

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --optimize-autoloader \
    --no-scripts

COPY . .

ENV APP_ENV=production \
    APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= \
    DB_CONNECTION=sqlite \
    DB_DATABASE=/tmp/database.sqlite \
    CACHE_DRIVER=file \
    QUEUE_CONNECTION=sync \
    SESSION_DRIVER=file \
    MAIL_MAILER=log

RUN composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --optimize-autoloader \
    --no-scripts \
 && php artisan vendor:publish --tag=laravel-assets --ansi --force \
 && php artisan lang:update || true \
 && mkdir -p storage/app storage/framework/cache storage/framework/sessions storage/framework/views \
 && touch storage/app/ISINSTALLED

FROM node:20-alpine AS frontend
WORKDIR /var/www/html

RUN apk add --no-cache python3 make g++

COPY package.json package-lock.json ./
RUN npm ci

COPY resources resources
COPY webpack.mix.js ./
COPY public public

RUN npm run production

FROM ${BASE_IMAGE} AS runtime

ENV LINKSTACK_SOURCE=/opt/linkstack

WORKDIR /opt/linkstack

COPY --from=composer_deps /var/www/html /opt/linkstack
COPY --from=frontend /var/www/html/public /opt/linkstack/public

RUN set -eux; \
    mkdir -p /htdocs; \
    rm -rf /htdocs/*; \
    cp -a /opt/linkstack/. /htdocs/; \
    (chown -R www-data:www-data /opt/linkstack /htdocs || true); \
    (chown -R apache:apache /opt/linkstack /htdocs || true)

VOLUME ["/htdocs"]
