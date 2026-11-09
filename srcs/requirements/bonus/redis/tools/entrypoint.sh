#!/bin/sh

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