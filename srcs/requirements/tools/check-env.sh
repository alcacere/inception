#!/bin/sh
# check-env.sh (runs on the VM host, called by `make` before `up`)    READ: docs/01, 09
#
# PURPOSE
#   Fail EARLY with a clear message instead of a half-started stack.
#
# WRITE (`set -eu`)

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

cd "$REPO_ROOT"

if [ ! -f "srcs/.env" ]; then
	echo "ERROR: srcs/.env file is missing. please run 'make secrets' first" >&2
	exit 1
fi

REQUIRED_VARS="
LOGIN
DOMAIN_NAME
DATA_PATH
MYSQL_DATABASE
MYSQL_USER
WP_TITLE
WP_ADMIN_USER
WP_ADMIN_EMAIL
WP_USER
WP_USER_EMAIL
WP_USER_ROLE
CERT_COUNTRY
CERT_STATE
CERT_CITY
CERT_ORG
CERT_UNIT
"

for var in $REQUIRED_VARS; do
	if ! grep -q "^${var}=." srcs/.env; then
		echo "ERROR: variable '${var}' is missing or empty in srcs/.env" >&2
		exit 1
	fi
done

REQUIRED_SECRETS="
db_password
db_root_password
wp_admin_password
wp_user_password
"

for secret in $REQUIRED_SECRETS; do
	file="secrets/${secret}.txt"
	if [ ! -s "$file" ]; then
		echo "ERROR: secret file '${file}' is missing or empty. Run 'make secrets' to generate it" >&2
		exit 1
	fi
done

WP_ADMIN_USER=$(grep 'WP_ADMIN_USER=' srcs/.env | cut -d= -f2- | tr -d ' "\r')

if echo "$WP_ADMIN_USER" | grep -qi "admin"; then
	echo "ERROR: WP_ADMIN_USER ('$WP_ADMIN_USER') contains 'admin'. this violates subject rules" >&2
	exit 1
fi

DOMAIN_NAME=$(grep '^DOMAIN_NAME=' srcs/.env | cut -d= -f2- | tr -d ' "\r')

LOGIN=$(grep '^LOGIN=' srcs/.env | cut -d= -f2- | tr -d ' "\r')

if [ "$DOMAIN_NAME" != "${LOGIN}.42.fr" ]; then
	echo "ERROR: DOMAIN_NAME ('$DOMAIN_NAME') must be '${LOGIN}.42.fr'" >&2
	exit 1
fi

if ! getent hosts "$DOMAIN_NAME" > /dev/null 2>&1; then
	echo "ERROR: domain '$DOMAIN_NAME' does not resolve. ensure it is mapped to 127.0.0.1 in /etc/hosts" >&2
	exit 1
fi

exit 0
