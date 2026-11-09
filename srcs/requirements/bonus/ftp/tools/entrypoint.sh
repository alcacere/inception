#!/bin/sh

set -eu

if [ -f /run/secrets/ftp_password ]; then
	FTP_PASSWORD=$(cat /run/secrets/ftp_password)
else
	echo "[ERROR]: FTP password is missing" >&2
	exit 1
fi

FTP_USER="${FTP_USER:-ftp_user}"

if ! id "$FTP_USER" >/dev/null 2>&1; then
	adduser -D -h /var/www/html -s /bin/sh -u 1000 "$FTP_USER"
fi

echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd
unset FTP_PASSWORD

FTP_PASV_ADDRESS="${FTP_PASV_ADDRESS:-192.168.56.42}"
if ! grep -q "^pasv_address=" /etc/vsftpd/vsftpd.conf; then
	echo "pasv_address=${FTP_PASV_ADDRESS}" >> /etc/vsftpd/vsftpd.conf
else
	sed -i "s/^pasv_address=.*/pasv_address=${FTP_PASV_ADDRESS}/" /etc/vsftpd/vsftpd.conf
fi

mkdir -p /var/run/vsftpd/empty
mkdir -p /var/www/html
chown -R 1000:1000 /var/www/html
echo "[INFO] vsftpd configured for user ${FTP_USER} (pasv_address=${FTP_PASV_ADDRESS})"
exec "$@"