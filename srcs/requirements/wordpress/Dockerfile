FROM alpine:3.23

RUN apk update && apk add --no-cache \
    php84 \
    php84-fpm \
    php84-mysqli \
    php84-phar \
    php84-curl \
    php84-dom \
    php84-mbstring \
    php84-xml \
    php84-gd \
    php84-zip \
    php84-intl \
    php84-opcache \
    php84-tokenizer \
    php84-ctype \
    php84-session \
    php84-iconv \
    php84-fileinfo \
    php84-openssl \
	php84-pecl-redis \
    mariadb-client \
    curl \
    fcgi

RUN echo "memory_limit = 512M" > /etc/php84/conf.d/memory-limit.ini

RUN ln -sf /usr/bin/php84 /usr/bin/php

RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

WORKDIR /var/www/html

RUN adduser -D -H -u 1000 -s /sbin/nologin www

RUN chown -R www:www /var/www/html

COPY conf/www.conf /etc/php84/php-fpm.d/www.conf

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

CMD [ "php-fpm84", "-F" ]
