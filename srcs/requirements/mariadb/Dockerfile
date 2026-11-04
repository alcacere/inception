# MariaDB Dockerfile                                     READ: docs/03, 08
#
# PURPOSE: image with ONLY MariaDB (no nginx: the eval greps for it).
#
# WRITE
#   FROM alpine:3.23          ☠ penultimate stable, never `latest`
#   RUN apk add --no-cache mariadb mariadb-client
#       + mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld /var/lib/mysql
#   COPY conf/<file>.cnf  → /etc/my.cnf.d/   (enables TCP: skip-networking=0, bind 0.0.0.0)
#   COPY tools/entrypoint.sh → /usr/local/bin/ ; RUN chmod +x
#   EXPOSE 3306                documentation only
#   USER mysql                 non-root (the entrypoint must then work as mysql)
#     ⚠ OWNERSHIP TRAP: the volume is really /home/alcacere/data/mariadb on the VM,
#       created by the Makefile and owned by YOUR uid. The image's chown does NOT apply
#       to a mounted dir. Pick one approach and be able to explain it:
#       a) the entrypoint runs as root, chowns /var/lib/mysql, then drops privileges
#          (`exec su-exec mysql "$@"`, apk add su-exec), or mariadbd --user=mysql
#       b) give the mysql user in the image the same uid as the owner of the host dir
#   ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]     exec form
#   CMD ["mariadbd"]                                 the real PID 1 after `exec "$@"`
#
# ☠ NO passwords here (no ENV/ARG with secrets).
#
# CHECK
#   docker history mariadb:<tag>   → no secret visible in any layer
