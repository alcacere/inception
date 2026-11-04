#!/bin/sh
# generate-secrets.sh (runs on the VM host, called by `make secrets`)   READ: docs/05, 09
#
# PURPOSE
#   Make a fresh `git clone` runnable without committing any credential:
#   create every missing secret file with a random password, and create
#   srcs/.env from srcs/.env.example if it's missing.
#
# WHY HERE
#   The subject's example tree has srcs/requirements/tools/ for helper scripts.
#
# WRITE (`set -eu`, resolve the repo root from the script path)
#   1. umask 077 so the new files are readable only by you (chmod 600)
#   2. mkdir -p secrets
#   3. for each name in: db_password db_root_password wp_admin_password
#                        wp_user_password ftp_password redis_password
#      if secrets/<name>.txt is missing or empty → openssl rand -base64 24 | tr -d '\n' > file
#      (NEVER overwrite an existing one: the DB was initialized with it!)
#   4. if srcs/.env is missing → cp srcs/.env.example srcs/.env and tell the user
#      to review it
#   5. print a summary (file names only, NEVER the passwords)
#
# CHECK
#   run it twice → the second run changes nothing (idempotent)
