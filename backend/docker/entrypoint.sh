#!/bin/sh
# Container start: listen on Render's PORT, cache config built from the runtime environment,
# then run Apache in the foreground. Never runs migrations.
set -eu

PORT="${PORT:-10000}"
sed -i "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

# APP_URL defaults to the URL Render assigns to the service.
if [ -z "${APP_URL:-}" ] && [ -n "${RENDER_EXTERNAL_URL:-}" ]; then
    export APP_URL="$RENDER_EXTERNAL_URL"
fi

if [ -z "${APP_KEY:-}" ]; then
    echo "APP_KEY is not set: refusing to start (use the existing application key)." >&2
    exit 1
fi

# Environment variables exist only at runtime, so the config cache is built here.
php artisan config:cache
php artisan view:cache
chown -R www-data:www-data storage bootstrap/cache

exec apache2-foreground
