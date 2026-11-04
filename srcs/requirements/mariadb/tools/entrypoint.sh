#!/bin/sh
# MariaDB entrypoint                                     READ: docs/08, 09
#
# PURPOSE
#   First start: initialize the datadir + run the one-time SQL.
#   Every start: hand over to mariadbd as PID 1.
#
# WRITE (`set -eu`)
#   1. If "$1" is not mariadbd → exec "$@"  (lets you run `docker run img sh` for debugging)
#   2. Read secrets: DB_PASS=$(cat /run/secrets/db_password), ROOT_PASS=...
#   3. if [ ! -d /var/lib/mysql/mysql ]  → FIRST RUN:
#        a. mariadb-install-db --user=mysql --datadir=/var/lib/mysql
#             --auth-root-authentication-method=normal  ☠ (else root logs in without a password!)
#             --skip-test-db
#        b. build the SQL (heredoc): FLUSH PRIVILEGES; ALTER USER root@localhost
#           IDENTIFIED BY ...; delete anonymous users; CREATE DATABASE IF NOT EXISTS;
#           CREATE USER IF NOT EXISTS '<user>'@'%' ...; GRANT ALL ON <db>.*; FLUSH PRIVILEGES;
#        c. run it WITHOUT a background server: mariadbd --bootstrap < file (or stdin)
#           (alternative: temporary server + BOUNDED ping loop, see docs/08 option B)
#        d. never leave the SQL file on disk with passwords (use stdin, or delete it)
#   4. exec "$@"  → mariadbd becomes PID 1
#
# ☠ No `&` for the final process, no infinite loop, no tail -f.
#
# CHECK
#   docker compose restart mariadb   → logs show NO re-initialization
#   docker exec -it mariadb mariadb -u root    → Access denied
