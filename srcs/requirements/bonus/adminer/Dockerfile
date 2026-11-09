FROM alpine:3.23

RUN apk update && apk add --no-cache \
	php84 \
	php84-fpm \
	php84-mysqli \
	php84-session \
	curl \
	fcgi

RUN mkdir -p /var/www/adminer

RUN curl -sSLo /var/www/adminer/index.php https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php \
    && echo "2fd7e6d8f987b243ab1839249551f62adce19704c47d3d0c8dd9e57ea5b9c6b3  /var/www/adminer/index.php" | sha256sum -c - \
    && chmod 444 /var/www/adminer/index.php

COPY conf/www.conf /etc/php84/php-fpm.d/www.conf

EXPOSE 9000

CMD ["php-fpm84", "-F"]