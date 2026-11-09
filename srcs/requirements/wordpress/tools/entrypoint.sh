#!/bin/sh
set -eu

if [ "$1" != "php-fpm84" ]; then
	exec "$@"
fi

if [ ! -f /run/secrets/db_password ] || [ ! -f /run/secrets/wp_admin_password ] || [ ! -f /run/secrets/wp_user_password ]; then
	echo "[ERROR] required secret files not found" >&2
	exit 1
fi

DB_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

if [ ! -f /var/www/html/wp-config.php ]; then
	echo "[INFO] wordpress not configured. begining installation..."

	wp core download --path=/var/www/html --allow-root
	
	wp config create --path=/var/www/html --allow-root \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost="mariadb:3306" \
		--skip-check

	wp core install --path=/var/www/html --allow-root \
	--url="https://${DOMAIN_NAME}" \
	--title="${WP_TITLE}" \
	--admin_user="${WP_ADMIN_USER}" \
	--admin_password="${WP_ADMIN_PASSWORD}" \
	--admin_email="${WP_ADMIN_EMAIL}" \
	--skip-email

	wp user create "${WP_USER}" "${WP_USER_EMAIL}" --path=/var/www/html --allow-root \
	--role="${WP_USER_ROLE:-author}" \
	--user_pass="${WP_USER_PASSWORD}"

	echo "[INFO] configuring redis object cache.."
	wp config set WP_REDIS_HOST "redis" --allow-root --path=/var/www/html
	wp config set WP_REDIS_TIMEOUT 1 --raw --allow-root --path=/var/www/html
	wp config set WP_REDIS_READ_TIMEOUT 1 --raw --allow-root --path=/var/www/html
	wp config set WP_REDIS_GRACEFUL true --raw --allow-root --path=/var/www/html
	if [ -f /run/secrets/redis_password ]; then
		REDIS_PASS=$(cat /run/secrets/redis_password)
		wp config set WP_REDIS_PASSWORD "$REDIS_PASS" --allow-root --path=/var/www/html
	fi

	wp plugin install redis-cache --activate --allow-root --path=/var/www/html
	wp redis enable --allow-root --path=/var/www/html || true

	echo "[INFO] wordpress installation complete"

	else
		echo "[INFO] wordpress is alredy installed. skipping initial setup"
fi

chown -R www:www /var/www/html

find /var/www/html -type d -exec chmod 755 {} +
find /var/www/html -type f -exec chmod 644 {} +
chmod 640 /var/www/html/wp-config.php

echo "[INFO] starting PHP-FPM..."

exec "$@"