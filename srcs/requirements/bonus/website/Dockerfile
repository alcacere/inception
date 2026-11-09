FROM alpine:3.23

RUN adduser -D -H -u 1000 www \
    && mkdir -p /var/www/site

COPY site/ /var/www/site/

RUN chown -R www:www /var/www/site

USER www

EXPOSE 8080

CMD ["busybox", "httpd", "-f", "-p", "8080", "-h", "/var/www/site"]