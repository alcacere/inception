FROM alpine:3.23

RUN apk update && apk add --no-cache \
	redis \
	gettext

COPY conf/redis.conf.template /etc/redis/redis.conf.template

COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 6379

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["redis-server", "/etc/redis/redis.conf"]

