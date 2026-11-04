# WordPress + PHP-FPM Dockerfile                         READ: docs/03, 07
#
# PURPOSE: WordPress + php-fpm ONLY (☠ no nginx in this file).
#
# WRITE
#   FROM alpine:3.23
#   RUN apk add --no-cache php84 php84-fpm php84-mysqli php84-phar
#       php84-curl php84-dom php84-mbstring php84-xml php84-gd php84-zip php84-intl
#       php84-opcache php84-tokenizer php84-ctype (+ php84-pecl-redis for the bonus)
#       mariadb-client (WP-CLI's `wp db` uses it) fcgi (healthcheck: cgi-fcgi)
#       → check each name exists: https://pkgs.alpinelinux.org/packages?branch=v3.23
#   RUN ln -s /usr/bin/php84 /usr/bin/php    (wp-cli calls `php`)
#   RUN download wp-cli.phar (pinned version) + VERIFY its sha512, install to
#       /usr/local/bin/wp
#   (choice) download WordPress core at build (wp core download into /usr/src/...)
#       → copy into the volume on first run; OR download at runtime. Explain why.
#   COPY conf/www.conf → /etc/php84/php-fpm.d/www.conf (replace the default pool)
#   COPY tools/entrypoint.sh → /usr/local/bin/ ; chmod +x
#   create the user that runs FPM (same uid as the ftp user for the bonus)
#   WORKDIR /var/www/html
#   EXPOSE 9000
#   ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
#   CMD ["php-fpm84", "-F"]          -F = foreground → PID 1
#
# ☠ No passwords (no ENV WP_ADMIN_PASSWORD=...).
