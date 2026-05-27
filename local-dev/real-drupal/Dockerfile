FROM php:8.3-apache

RUN apt-get update \
  && apt-get install -y \
    git \
    unzip \
    default-mysql-client \
    curl \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    msmtp \
    msmtp-mta \
    mailutils \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install pdo pdo_mysql zip gd \
  && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN composer create-project drupal/recommended-project:^10 /var/www/html \
  && cd /var/www/html \
  && composer require drush/drush:^12

RUN sed -ri -e "s!/var/www/html!/var/www/html/web!g" /etc/apache2/sites-available/000-default.conf \
  && printf '%s\n' 'ServerName localhost' > /etc/apache2/conf-available/servername.conf \
  && a2enconf servername \
  && a2enmod rewrite \
  && { \
    echo '<Directory /var/www/html/web>'; \
    echo '  Options Indexes FollowSymLinks'; \
    echo '  AllowOverride All'; \
    echo '  Require all granted'; \
    echo '</Directory>'; \
  } > /etc/apache2/conf-available/drupal.conf \
  && a2enconf drupal

COPY entrypoint.sh /usr/local/bin/real-drupal-entrypoint
RUN chmod +x /usr/local/bin/real-drupal-entrypoint

WORKDIR /var/www/html

ENTRYPOINT ["real-drupal-entrypoint"]
CMD ["apache2-foreground"]
