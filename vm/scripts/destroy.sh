#!/bin/sh
# destroy.sh - Destroy the Inception VM and optionally unregister the box

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$VM_DIR"

echo "==> Destroying Inception VM..."
vagrant destroy -f

if [ "${1:-}" = "--all" ] || [ "${1:-}" = "-a" ]; then
    echo "==> Removing Vagrant box 'inception-debian'..."
    vagrant box remove -f inception-debian 2>/dev/null || true
    rm -rf "$VM_DIR/packer/output" "$VM_DIR/.vagrant"
    echo "==> All VM resources, box files, and local state destroyed."
else
    echo "==> VM destroyed. (Box 'inception-debian' preserved for quick re-launch)."
    echo "    To completely remove the box as well, run: ./scripts/destroy.sh --all"
fi
