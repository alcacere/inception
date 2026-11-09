#!/bin/sh

set -eu

mkdir -p /etc/nginx/ssl /run/nginx /etc/nginx/http.d

if [ ! -f /etc/nginx/ssl/inception.crt ] || [ ! -f /etc/nginx/ssl/inception.key ]; then
	echo "[INFO] generating 2-tier TLS certificates for ${DOMAIN_NAME}..."

	if [ ! -f /etc/nginx/ssl/rootCA.crt ] || [ ! -f /etc/nginx/ssl/rootCA.key ]; then
			openssl req -x509 -new -nodes -keyout /etc/nginx/ssl/rootCA.key -out /etc/nginx/ssl/rootCA.crt -days 3650 \
			-subj "/C=ES/ST=Madrid/L=Madrid/O=42Madrid/CN=Inception Local Root CA" \
			-addext "basicConstraints=critical,CA:TRUE" \
			-addext "keyUsage=critical,keyCertSign,cRLSign" \
			-addext "nameConstraints=critical,permitted;DNS:${DOMAIN_NAME:-alcacere.42.fr}"
		chmod 600 /etc/nginx/ssl/rootCA.key
		chmod 644 /etc/nginx/ssl/rootCA.crt
	fi

	openssl req -new -nodes -keyout /etc/nginx/ssl/inception.key -out /tmp/inception.csr \
		-subj "/C=ES/ST=Madrid/L=Madrid/O=42Madrid/CN=${DOMAIN_NAME}"

	openssl x509 -req -in /tmp/inception.csr -CA /etc/nginx/ssl/rootCA.crt -CAkey /etc/nginx/ssl/rootCA.key -CAcreateserial \
		-out /etc/nginx/ssl/inception.crt -days 365 \
		-extfile - <<EOF
subjectAltName=DNS:${DOMAIN_NAME}
basicConstraints=critical,CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EOF

	rm -f /tmp/inception.csr
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