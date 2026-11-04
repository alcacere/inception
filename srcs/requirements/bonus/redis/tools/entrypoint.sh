#!/bin/sh
# Redis entrypoint                                       READ: docs/10 §1, 09
#
# WRITE (`set -eu`)
#   1. REDIS_PASSWORD=$(cat /run/secrets/redis_password); export it only for envsubst
#   2. envsubst '${REDIS_PORT} ${REDIS_PASSWORD}' < template > /etc/redis/redis.conf
#      chmod 600 the rendered file; unset REDIS_PASSWORD
#   3. exec "$@"
