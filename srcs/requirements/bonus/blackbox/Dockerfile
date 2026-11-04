# Blackbox Exporter Dockerfile (bonus, free choice: part 1/2)   READ: docs/10 §5
#
# PURPOSE: probe services over the network and expose the results as metrics.
#          No host mounts, no docker.sock, no capabilities: that's why it replaced cAdvisor.
#
# WRITE
#   FROM alpine:3.23
#   RUN apk add --no-cache prometheus-blackbox-exporter
#   COPY conf/blackbox.yml → /etc/prometheus/blackbox.yml
#   USER prometheus            (this user comes with the package)
#   EXPOSE 9115                documentation only: NEVER publish this port
#   CMD ["blackbox_exporter", "--config.file=/etc/prometheus/blackbox.yml"]
#
# In compose: cap_drop [ALL], security_opt no-new-privileges:true, read_only: true,
#   no ports, no volumes. The network shared with its targets and with prometheus.
#
# CHECK
#   docker exec blackbox wget -qO- "http://127.0.0.1:9115/probe?target=nginx:443&module=tcp"
#   → probe_success 1
