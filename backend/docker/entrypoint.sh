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

missing=""
for name in APP_KEY DB_HOST DB_PORT DB_DATABASE DB_USERNAME DB_PASSWORD; do
    eval "value=\${$name:-}"
    [ -n "$value" ] || missing="$missing $name"
done
if [ -n "$missing" ]; then
    echo "Refusing to start: missing required environment variables:$missing" >&2
    exit 1
fi

# TLS to the database (e.g. Aiven): the provider's CA certificate (public, not a secret) is passed as
# DB_SSL_CA_PEM and written to a file that PDO verifies the server certificate against.
if [ -n "${DB_SSL_CA_PEM:-}" ]; then
    printf '%s\n' "$DB_SSL_CA_PEM" > /etc/ssl/certs/db-ca.pem
    chmod 644 /etc/ssl/certs/db-ca.pem
    export MYSQL_ATTR_SSL_CA=/etc/ssl/certs/db-ca.pem
fi

# Environment variables exist only at runtime, so the config cache is built here.
php artisan config:cache
php artisan view:cache
chown -R www-data:www-data storage bootstrap/cache

exec apache2-foreground
