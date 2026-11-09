FROM alpine:3.23

RUN apk update && apk add --no-cache prometheus \
	&& mkdir -p /prometheus \
	&& chown -R prometheus:prometheus /prometheus

COPY conf/prometheus.yml /etc/prometheus/prometheus.yml
COPY conf/alerts.yml /etc/prometheus/alerts.yml

USER prometheus

EXPOSE 9090

VOLUME ["/prometheus"]

CMD ["prometheus", \
	"--config.file=/etc/prometheus/prometheus.yml", \
	"--storage.tsdb.path=/prometheus", \
	"--storage.tsdb.retention.time=7d", \
	"--web.external-url=https://alcacere.42.fr/prometheus/", \
	"--web.route-prefix=/"]
