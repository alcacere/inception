#!/bin/sh
# up.sh - Start (or build and start) the Inception VM

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$VM_DIR"

"$SCRIPT_DIR/cluster-setup.sh"

# Check if the box is registered; if not, build it automatically
if ! vagrant box list 2>/dev/null | grep -q "^inception-debian "; then
    echo "==> Box 'inception-debian' is not yet registered. Running build-box.sh..."
    "$SCRIPT_DIR/build-box.sh"
fi

echo "==> Bringing up the Inception VM with Vagrant..."
vagrant up

echo ""
echo "=========================================================="
echo "  Inception VM is running!"
echo "=========================================================="
echo "  * Connect via SSH:    make vm-ssh   (or: cd vm && vagrant ssh)"
echo "  * Work as project:    sudo -iu alcacere"
echo "  * Synced folder:      /home/alcacere/inception"
echo "  * Web URL:            https://alcacere.42.fr"
echo "                        (Ensure '192.168.56.42 alcacere.42.fr' is in /etc/hosts)"
echo "=========================================================="
