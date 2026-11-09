#!/bin/sh
# Redis entrypoint                                       READ: docs/10 §1, 09
#
# WRITE (`set -eu`)
#   1. REDIS_PASSWORD=$(cat /run/secrets/redis_password); export it only for envsubst
#   2. envsubst '${REDIS_PORT} ${REDIS_PASSWORD}' < template > /etc/redis/redis.conf
#      chmod 600 the rendered file; unset REDIS_PASSWORD
#   3. exec "$@"

set -eu

if [ -f /run/secrets/redis_password ]; then
	REDIS_PASSWORD=$(cat /run/secrets/redis_password)
else
	REDIS_PASSWORD=""
fi

export REDIS_PASSWORD
export REDIS_PORT="${REDIS_PORT:-6379}"

mkdir -p /etc/redis
envsubst '${REDIS_PORT} ${REDIS_PASSWORD}' < /etc/redis/redis.conf.template > /etc/redis/redis.conf
chmod 600 /etc/redis/redis.conf
unset REDIS_PASSWORD

exec "$@"