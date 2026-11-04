#!/bin/sh
#
# PURPOSE
#   Make a fresh `git clone` runnable without committing any credential:
#   create every missing secret file with a random password, and create
#   srcs/.env from srcs/.env.example if it's missing.
#

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

cd "$REPO_ROOT"

umask 077

mkdir -p secrets

echo "==> Configuring secrets in secrets/..."

for name in \
    db_password \
    db_root_password \
    wp_admin_password \
    wp_user_password \
    ftp_password \
    redis_password
do
    file="secrets/${name}.txt"
    if [ ! -s "$file" ]; then
        openssl rand -base64 24 | tr -d '\n' > "$file"
        echo "  [created]  $file"
    else
        echo "  [existing] $file"
    fi
done

if [ ! -f "srcs/.env" ]; then
    cp srcs/.env.example srcs/.env
    echo "  [created]  srcs/.env (copied from srcs/.env.example)"
else
    echo "  [existing] srcs/.env"
fi
