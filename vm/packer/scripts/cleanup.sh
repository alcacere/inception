#!/bin/sh
# cleanup.sh - Clean caches and zero empty space to minimize box image size

set -eu

echo "==> Cleaning APT package cache..."
apt-get autoremove -y --purge
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "==> Cleaning machine-specific IDs and temporary files..."
# Truncate machine-id (do not delete file; systemd generates a fresh one on first boot if empty)
: > /etc/machine-id
if [ -f /var/lib/dbus/machine-id ]; then
    : > /var/lib/dbus/machine-id
fi

rm -rf /tmp/* /var/tmp/*
find /var/log -type f -exec truncate --size 0 {} +

# The build password is no longer needed: remove its hash, so only SSH keys can log in.
usermod -p '!' vagrant

# Clear shell history
unset HISTFILE
rm -f /root/.bash_history /home/*/.bash_history

echo "==> Zeroing out free disk space for compression..."
# dd fills disk with zeros until it naturally runs out of space, ensuring high gzip/box compression
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY

sync
echo "==> Cleanup complete!"
