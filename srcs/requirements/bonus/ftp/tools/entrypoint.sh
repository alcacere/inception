#!/bin/sh
# FTP entrypoint                                         READ: docs/10 §2, 09
#
# WRITE (`set -eu`)
#   1. echo "${FTP_USER}:$(cat /run/secrets/ftp_password)" | chpasswd
#      (sets the password at runtime: never in the Dockerfile)
#   2. (if pasv_address comes from env) render it into the config
#   3. mkdir -p /var/run/vsftpd/empty   (vsftpd's secure_chroot_dir must exist)
#   4. exec "$@"
