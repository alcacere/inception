FROM alpine:3.23

RUN apk update && apk add --no-cache prometheus-blackbox-exporter

COPY conf/blackbox.yml /etc/prometheus/blackbox.yml

USER prometheus

EXPOSE 9115

CMD [ "blackbox_exporter", "--config.file=/etc/prometheus/blackbox.yml" ]