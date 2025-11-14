# Dockerfile para aplicação PHP
FROM php:8.2-fpm-alpine

# Informações do container
LABEL maintainer="Paulo Ramos <paulorhramos@example.com>"
LABEL description="Container PHP-FPM para desenvolvimento"
LABEL version="1.0"

# Instalar extensões PHP e dependências
RUN apk add --no-cache \
    nginx \
    git \
    unzip \
    curl \
    postgresql-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    bash

# Instalar extensões PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    gd \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    mysqli \
    zip \
    intl \
    mbstring \
    opcache \
    bcmath

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configurar PHP
COPY ./development/php/php.ini /usr/local/etc/php/conf.d/custom.ini

# Criar diretório da aplicação
WORKDIR /var/www/html

# Criar usuário não-root
RUN adduser -D -s /bin/bash appuser && \
    chown -R appuser:appuser /var/www/html

USER appuser

# Expor porta
EXPOSE 9000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9000/health.php || exit 1

# Comando padrão
CMD ["php-fpm"]