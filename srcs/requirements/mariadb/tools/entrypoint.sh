#!/bin/sh

set -eu

if [ "$1" != "mariadbd" ]; then
	exec "$@"
fi

DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

MYSQL_DATABASE="${MYSQL_DATABASE:-wordpress}"
MYSQL_USER="${MYSQL_USER:-wp_dbuser}"

if [ ! -d "/var/lib/mysql/mysql" ]; then
	echo "==> initializing MariaDB data directory..."

	chown -R mysql:mysql /run/mysqld /var/lib/mysql

	mariadb-install-db \
		--user=mysql \
		--datadir=/var/lib/mysql \
		--auth-root-authentication-method=normal \
		--skip-test-db

    echo "==> Configuring users and initial database..."
    mariadbd --user=mysql --bootstrap <<EOF
	FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
DELETE FROM mysql.global_priv WHERE User='' OR (User='root' AND Host != 'localhost');
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

fi

echo "==> Starting MariaDB server..."
exec "$@"