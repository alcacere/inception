#!/bin/sh
# build-box.sh - Produce and register the inception-debian Vagrant box

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$VM_DIR"

"$SCRIPT_DIR/cluster-setup.sh"

echo "==> Checking host prerequisites..."
for cmd in packer vagrant VBoxManage openssl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required tool '$cmd' is not installed or not in PATH." >&2
        exit 1
    fi
done

if ! VBoxManage list hostinfo >/dev/null 2>&1; then
    echo "ERROR: VirtualBox kernel module (vboxdrv) is not loaded." >&2
    echo "Hint: run 'sudo /sbin/vboxconfig' on the host." >&2
    exit 1
fi

echo "==> Generating a temporary build password (kept in memory only)..."
PKR_VAR_ssh_password="$(openssl rand -hex 24)"
PKR_VAR_ssh_password_hash="$(printf '%s' "$PKR_VAR_ssh_password" | openssl passwd -6 -stdin)"
export PKR_VAR_ssh_password PKR_VAR_ssh_password_hash

echo "==> Initializing and validating Packer template..."
packer init packer
packer validate packer

echo "==> Building Debian image with Packer (unattended installation)..."
packer build -force packer

BOX_PATH="$VM_DIR/packer/output/inception-debian.box"
if [ ! -f "$BOX_PATH" ]; then
    echo "ERROR: Expected box file not found at $BOX_PATH" >&2
    exit 1
fi

echo "==> Registering inception-debian box with Vagrant..."
vagrant box add --force --name inception-debian "$BOX_PATH"

echo "==> Success! Box 'inception-debian' is built and registered."
echo "==> Next step: run 'make vm' or 'vagrant up' to start the machine."
