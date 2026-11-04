#!/bin/sh
# check-env.sh (runs on the VM host, called by `make` before `up`)    READ: docs/01, 09
#
# PURPOSE
#   Fail EARLY with a clear message instead of a half-started stack.
#
# WRITE (`set -eu`)
#   1. srcs/.env exists, else: "run make secrets"
#   2. every required variable is present and non-empty
#      (list them once; grep -q "^VAR=." srcs/.env)
#   3. every secret file exists and is non-empty
#   4. ☠ subject rule: the WordPress admin username must NOT contain admin/administrator
#      in any case → e.g. echo "$WP_ADMIN_USER" | grep -qi admin && fail
#   5. the domain is <login>.42.fr and resolves (getent hosts "$DOMAIN_NAME")
#   6. exit 0 silently when everything is fine
