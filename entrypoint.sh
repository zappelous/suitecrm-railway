#!/bin/bash
set -e

# Fix Apache MPM conflict at runtime (guarantee only mpm_prefork is enabled)
rm -f /etc/apache2/mods-enabled/mpm_*.conf /etc/apache2/mods-enabled/mpm_*.load
ln -s /etc/apache2/mods-available/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf
ln -s /etc/apache2/mods-available/mpm_prefork.load /etc/apache2/mods-enabled/mpm_prefork.load

# Configure Apache to listen on Railway's $PORT (default 80)
APACHE_PORT="${PORT:-80}"
sed -i "s/^Listen 80/Listen ${APACHE_PORT}/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${APACHE_PORT}>/g" /etc/apache2/sites-available/000-default.conf
grep -q "ServerName" /etc/apache2/apache2.conf || echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Create persistent directories if they don't exist
mkdir -p /data/suitecrm/upload
mkdir -p /data/suitecrm/cache
mkdir -p /data/suitecrm/custom

# Function to setup persistent directory
try_persist_dir() {
    local src="$1"
    local dst="$2"
    
    # If persistent dir is empty, seed it from container
    if [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
        if [ -d "$dst" ] && [ ! -L "$dst" ]; then
            cp -a "$dst/." "$src/" 2>/dev/null || true
        fi
    fi
    
    # Remove original and symlink
    if [ -d "$dst" ] && [ ! -L "$dst" ]; then
        rm -rf "$dst"
    fi
    if [ ! -L "$dst" ]; then
        ln -sfn "$src" "$dst"
    fi
}

# Only symlink directories that truly need persistence
try_persist_dir /data/suitecrm/upload /var/www/html/upload
try_persist_dir /data/suitecrm/cache /var/www/html/cache
try_persist_dir /data/suitecrm/custom /var/www/html/custom

# Handle config files
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

# Fix ownership only on symlinks and config files (fast)
chown -h www-data:www-data /var/www/html/upload /var/www/html/cache /var/www/html/custom 2>/dev/null || true
chown www-data:www-data /data/suitecrm/config.php 2>/dev/null || true
chown www-data:www-data /data/suitecrm/config_override.php 2>/dev/null || true

# Start cron in background (non-blocking)
cron 2>/dev/null || true

# Execute passed command
exec "$@"
