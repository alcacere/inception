# FTP (vsftpd) Dockerfile (bonus)                        READ: docs/10 §2
#
# Service/image name: ftp
#
# WRITE
#   FROM alpine:3.23
#   RUN apk add --no-cache vsftpd
#   RUN create the FTP user with the SAME uid/gid as the WordPress FPM user
#       (home = the WordPress web root, shell /sbin/nologin)
#   COPY conf/vsftpd.conf → /etc/vsftpd/vsftpd.conf
#   COPY tools/entrypoint.sh
#   EXPOSE 21 21000-21010
#   ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
#   CMD ["vsftpd", "/etc/vsftpd/vsftpd.conf"]
#
# In compose: `init: true` (vsftpd forks one process per session → zombie reaping),
# volume wordpress, ports 21 + passive range, secret ftp_password.

FROM alpine:3.23

RUN apk update && apk add --no-cache vsftpd

COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 21 21000-21010

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

CMD ["vsftpd", "/etc/vsftpd/vsftpd.conf"]