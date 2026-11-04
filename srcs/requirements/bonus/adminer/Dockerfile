# Adminer Dockerfile (bonus)                             READ: docs/10 §4
#
# WRITE
#   FROM alpine:3.23
#   RUN apk add --no-cache php84 php84-fpm php84-mysqli php84-session fcgi
#   RUN download adminer-<pinned version>.php from the official GitHub releases
#       to /var/www/adminer/index.php AND verify its sha256 (sha256sum -c)
#       → chmod 444 (read-only)
#   COPY conf/www.conf → /etc/php84/php-fpm.d/www.conf
#   USER <non-root>
#   EXPOSE 9000
#   CMD ["php-fpm84", "-F"]
#
# nginx: location ^~ /adminer → fastcgi_pass adminer:9000,
#        SCRIPT_FILENAME /var/www/adminer/index.php
# Login in the UI: server "mariadb", user/password of the WordPress DB user.
