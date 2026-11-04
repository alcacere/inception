#!/bin/sh
# WordPress entrypoint                                   READ: docs/07, 09
#
# PURPOSE
#   On first start, install AND configure WordPress with WP-CLI, so the evaluator
#   never sees the installation page. On later starts, skip straight to php-fpm.
#
# WRITE (`set -eu`)
#   1. If "$1" is not php-fpm84 → exec "$@"
#   2. Read secrets from /run/secrets/* into variables (never echo them)
#   3. if ! wp core is-installed (or wp-config.php is missing) → FIRST RUN:
#        a. get the core files into the web root (copy from /usr/src or wp core download)
#        b. wp config create --dbname --dbuser --dbpass --dbhost=mariadb:3306 --skip-check
#           (outstanding: like the reference, write PHP code that READS the secret file
#            at runtime instead of the password in clear: wp config set ... --raw)
#        c. wp core install --url="https://${DOMAIN_NAME}" --title ... --admin_user
#           (☠ no "admin" inside) --admin_password --admin_email --skip-email
#        d. wp user create <user> <email> --role=author --user_pass=...
#        e. BONUS redis: wp config set WP_REDIS_HOST/PORT/PASSWORD,
#           wp plugin install redis-cache --activate (or a pre-downloaded zip),
#           wp redis enable
#        f. fix ownership of the web root for the FPM user
#   4. exec "$@"  → php-fpm becomes PID 1
#
# NO "wait for mariadb" loop needed: compose `depends_on: condition: service_healthy`.
#
# CHECK
#   docker compose restart wordpress → logs say "already installed"
#   docker exec wordpress wp user list   → 2 users, admin name w/o "admin"
