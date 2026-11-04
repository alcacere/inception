# Prometheus Dockerfile (bonus, free choice: part 2/2)   READ: docs/10 §5
#
# PURPOSE: scrape blackbox and itself, store the time series, query them with PromQL.
#
# WRITE
#   FROM alpine:3.23
#   RUN apk add --no-cache prometheus        (community repo, v3.5.x on 3.23)
#   COPY conf/prometheus.yml and conf/alerts.yml → /etc/prometheus/
#   RUN mkdir -p /prometheus && chown prometheus:prometheus /prometheus
#   USER prometheus
#   EXPOSE 9090
#   CMD ["prometheus",
#        "--config.file=/etc/prometheus/prometheus.yml",
#        "--storage.tsdb.path=/prometheus",              ← dedicated volume
#        "--storage.tsdb.retention.time=7d",
#        "--web.external-url=https://alcacere.42.fr/prometheus/",
#        "--web.route-prefix=/"]                           (because nginx strips /prometheus/)
#
# Don't add --web.enable-admin-api or --web.enable-lifecycle: both are off by default, keep them off.
# Healthcheck: wget -qO- http://127.0.0.1:9090/-/healthy
