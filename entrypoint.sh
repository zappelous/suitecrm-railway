#!/bin/bash
set -e

# Create persistent directories if they don't exist
mkdir -p /data/suitecrm/upload
mkdir -p /data/suitecrm/cache
mkdir -p /data/suitecrm/custom
mkdir -p /data/suitecrm/modules
mkdir -p /data/suitecrm/themes
mkdir -p /data/suitecrm/data
mkdir -p /data/suitecrm/include

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

# Seed and link directories
try_persist_dir /data/suitecrm/upload /var/www/html/upload
try_persist_dir /data/suitecrm/cache /var/www/html/cache
try_persist_dir /data/suitecrm/custom /var/www/html/custom
try_persist_dir /data/suitecrm/modules /var/www/html/modules
try_persist_dir /data/suitecrm/themes /var/www/html/themes
try_persist_dir /data/suitecrm/data /var/www/html/data

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

# Set ownership
chown -R www-data:www-data /var/www/html /data/suitecrm

# Set writable permissions
chmod -R 775 /var/www/html/cache 2>/dev/null || true
chmod -R 775 /var/www/html/upload 2>/dev/null || true
chmod -R 775 /var/www/html/custom 2>/dev/null || true
chmod -R 775 /var/www/html/modules 2>/dev/null || true
chmod -R 775 /var/www/html/themes 2>/dev/null || true
chmod -R 775 /var/www/html/data 2>/dev/null || true
chmod 664 /var/www/html/config.php 2>/dev/null || true
chmod 664 /var/www/html/config_override.php 2>/dev/null || true

# Start cron
service cron start 2>/dev/null || cron

# Execute passed command
exec "$@"
