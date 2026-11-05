FROM alpine:3.23

RUN apk update && apk add --no-cache \
    nginx \
    openssl \
    gettext

RUN rm -f /etc/nginx/http.d/default.conf \
    && mkdir -p /etc/nginx/ssl /etc/nginx/templates /run/nginx /var/www/html

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/inception.conf.template /etc/nginx/templates/inception.conf.template
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]