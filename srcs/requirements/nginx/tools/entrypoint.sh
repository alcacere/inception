#!/bin/sh
set -eu

mkdir -p /etc/nginx/ssl /run/nginx /etc/nginx/http.d

if [ ! -f /etc/nginx/ssl/inception.crt ] || [ ! -f /etc/nginx/ssl/inception.key ]; then
	echo "[INFO] generating self-signed TLS certificate for ${DOMAIN_NAME}..."
	openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
		-keyout /etc/nginx/ssl/inception.key \
		-out /etc/nginx/ssl/inception.crt \
		-subj "/C=ES/ST=Madrid/L=Madrid/O=42Madrid/OU=42/CN=${DOMAIN_NAME}" \
		-addext "subjectAltName=DNS:${DOMAIN_NAME}" \
		-addext "basicConstraints=critical,CA:TRUE"

	chmod 600 /etc/nginx/ssl/inception.key
	chmod 644 /etc/nginx/ssl/inception.crt
	echo "[INFO] TLS certificate generated successfully"
fi

echo "[INFO] rendering NGINX configuration template..."
envsubst '${DOMAIN_NAME}' < /etc/nginx/templates/inception.conf.template > /etc/nginx/http.d/inception.conf

echo "[INFO] testing nginx configuration..."
nginx -t

echo "[INFO] starting nginx in foreground..."

exec "$@"