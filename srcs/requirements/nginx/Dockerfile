# NGINX Dockerfile                                       READ: docs/03, 06
#
# PURPOSE: the ONLY entry point. TLS 1.2/1.3 on port 443, serves WordPress static
#          files, forwards PHP to wordpress:9000 (FastCGI), proxies bonus UIs.
#
# WRITE
#   FROM alpine:3.23
#   RUN apk add --no-cache nginx openssl gettext   (gettext → envsubst)
#   RUN remove Alpine's default vhost (/etc/nginx/http.d/default.conf)
#       + mkdir the cert dir (e.g. /etc/nginx/ssl) and /run/nginx
#   COPY conf/nginx.conf → /etc/nginx/nginx.conf
#   COPY conf/inception.conf.template → somewhere the entrypoint renders it from
#   COPY tools/entrypoint.sh → /usr/local/bin/ ; chmod +x
#   EXPOSE 443                 ☠ no 80
#   (optional) run as non-root: then chown the dirs nginx writes to and give the
#              container cap NET_BIND_SERVICE in compose (port < 1024)
#   ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
#   CMD ["nginx", "-g", "daemon off;"]    (or `daemon off;` in nginx.conf + CMD ["nginx"])
#
# DESIGN DECISION TO EXPLAIN: generate the certificate at RUNTIME (entrypoint, only
# if missing) and not with RUN at build time → the private key never ends up in an
# image layer.
