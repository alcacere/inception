# Redis Dockerfile (bonus: WordPress object cache)       READ: docs/10 §1
#
# WRITE
#   FROM alpine:3.23
#   RUN apk add --no-cache redis gettext   (gettext only if you render the conf with envsubst)
#   COPY conf/redis.conf.template + tools/entrypoint.sh
#   EXPOSE 6379
#   USER redis
#   ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
#   CMD ["redis-server", "/etc/redis/redis.conf"]     foreground (daemonize no)
