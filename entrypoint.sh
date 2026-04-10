#!/bin/bash
set -e

# Ensure required directories exist
mkdir -p /data/suitecrm/upload /data/suitecrm/cache /data/suitecrm/custom

try_persist_dir() {
    local src="$1"
    local dst="$2"
    if [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
        if [ -d "$dst" ] && [ ! -L "$dst" ]; then
            cp -a "$dst/." "$src/" 2>/dev/null || true
        fi
    fi
    if [ -d "$dst" ] && [ ! -L "$dst" ]; then
        rm -rf "$dst"
    fi
    if [ ! -L "$dst" ]; then
        ln -sfn "$src" "$dst"
    fi
}

try_persist_dir /data/suitecrm/upload /var/www/html/upload
try_persist_dir /data/suitecrm/cache /var/www/html/cache
try_persist_dir /data/suitecrm/custom /var/www/html/custom

if [ ! -f /data/suitecrm/config.php ] && [ -f /var/www/html/config.php ] && [ ! -L /var/www/html/config.php ]; then
    cp /var/www/html/config.php /data/suitecrm/config.php
fi
if [ ! -f /data/suitecrm/config_override.php ] && [ -f /var/www/html/config_override.php ] && [ ! -L /var/www/html/config_override.php ]; then
    cp /var/www/html/config_override.php /data/suitecrm/config_override.php
fi

if [ -f /data/suitecrm/config.php ]; then
    ln -sfn /data/suitecrm/config.php /var/www/html/config.php
fi
touch /data/suitecrm/config_override.php 2>/dev/null || true
ln -sfn /data/suitecrm/config_override.php /var/www/html/config_override.php

chown -h www-data:www-data /var/www/html/upload /var/www/html/cache /var/www/html/custom 2>/dev/null || true
chown www-data:www-data /data/suitecrm/config.php 2>/dev/null || true
chown www-data:www-data /data/suitecrm/config_override.php 2>/dev/null || true

# Start cron
cron 2>/dev/null || true

# Substitute Railway $PORT into nginx config
PORT="${PORT:-80}"
sed -i "s/\${PORT}/${PORT}/g" /etc/nginx/nginx.conf

# Start php-fpm in background
php-fpm -D

# Start nginx in foreground
nginx -g 'daemon off;'
