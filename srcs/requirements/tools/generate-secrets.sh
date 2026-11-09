#!/bin/sh
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

cd "$REPO_ROOT"

umask 077

mkdir -p secrets

echo "==> Configuring secrets in secrets/..."

DATA_PATH="/home/${LOGIN:-alcacere}/data"
if [ -d "$DATA_PATH/mariadb/mysql" ] || [ -f "$DATA_PATH/wordpress/wp-config.php" ]; then
    missing=0
    for name in db_password db_root_password wp_admin_password wp_user_password ftp_password redis_password; do
        if [ ! -s "secrets/${name}.txt" ]; then
            missing=1
            break
        fi
    done
    if [ "$missing" -eq 1 ]; then
        echo "[ERROR] Existing data detected at $DATA_PATH but secrets are missing!" >&2
        echo "Generating new random secrets would desync from the existing database." >&2
        echo "Run 'make fclean' to clean old persistent data first, or restore your secrets." >&2
        exit 1
    fi
fi

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
