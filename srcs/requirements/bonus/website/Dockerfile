FROM alpine:3.23

RUN apk update && apk add --no-cache darkhttpd \
    && adduser -D -H -u 1000 www \
    && mkdir -p /var/www/site

COPY site/ /var/www/site/

RUN chown -R www:www /var/www/site

USER www

EXPOSE 8080

CMD ["darkhttpd", "/var/www/site", "--port", "8080"]
