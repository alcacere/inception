FROM alpine:3.23

RUN apk update && apk add --no-cache vsftpd

COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 21 21000-21010

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

CMD ["vsftpd", "/etc/vsftpd/vsftpd.conf"]