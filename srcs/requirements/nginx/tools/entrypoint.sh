#!/bin/sh
# NGINX entrypoint                                       READ: docs/06, 09
#
# WRITE (`set -eu`)
#   1. If the key/cert don't exist → openssl req -x509 -nodes -newkey rsa:2048 -days 365
#        -keyout ... -out ... -subj "/C=${CERT_COUNTRY}/.../CN=${DOMAIN_NAME}"
#        -addext "subjectAltName=DNS:${DOMAIN_NAME}"
#      chmod 600 the key.   (only if missing → fast restarts, stable fingerprint)
#   2. envsubst '${DOMAIN_NAME}' < template > /etc/nginx/http.d/inception.conf
#   3. nginx -t   (fail fast on a broken config; set -e stops the script)
#   4. exec "$@"  → nginx (foreground) becomes PID 1
#
# CHECK
#   openssl s_client -connect alcacere.42.fr:443 -tls1_2 / -tls1_3 → OK ; -tls1_1 → fails
