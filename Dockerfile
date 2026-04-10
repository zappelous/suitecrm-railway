FROM php:8.2-cli-bookworm

# Install dependencies
RUN apt-get update && apt-get install -y \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libpq-dev \
    unzip \
    git \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install -j$(nproc) \
    mysqli \
    pdo_mysql \
    pdo_pgsql \
    zip \
    mbstring \
    xml \
    curl \
    opcache

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application files
COPY . /var/www/html/

# Run composer install
RUN composer install --no-dev --optimize-autoloader --no-interaction || true

# Create data directory for persistent storage
RUN mkdir -p /data/suitecrm

# Set ownership and writable permissions
RUN chown -R www-data:www-data /var/www/html /data/suitecrm \
    && mkdir -p /var/www/html/cache /var/www/html/upload /var/www/html/custom /var/www/html/modules /var/www/html/themes /var/www/html/data /var/www/html/include /var/www/html/XTemplate /var/www/html/Zend \
    && chmod -R 775 /var/www/html/cache \
    /var/www/html/upload \
    /var/www/html/custom \
    /var/www/html/modules \
    /var/www/html/themes \
    /var/www/html/data \
    /var/www/html/include \
    /var/www/html/XTemplate \
    /var/www/html/Zend

# Copy and set up entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
