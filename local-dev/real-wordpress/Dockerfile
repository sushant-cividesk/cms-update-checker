FROM wordpress:php8.3-apache

RUN apt-get update \
  && apt-get install -y default-mysql-client curl less msmtp msmtp-mta mailutils rsync \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  && chmod +x /usr/local/bin/wp

COPY entrypoint.sh /usr/local/bin/real-wordpress-entrypoint
RUN chmod +x /usr/local/bin/real-wordpress-entrypoint

ENTRYPOINT ["real-wordpress-entrypoint"]
CMD ["apache2-foreground"]
