#!/bin/sh

set -eu

USER_NAME="${USER:-$(whoami)}"

CLUSTER_BASE=""
if [ -d "/sgoinfre" ]; then
	CLUSTER_BASE="/sgoinfre"
elif [ -d "/goinfre" ]; then
	CLUSTER_BASE="/goinfre"
fi

if [ -z "$CLUSTER_BASE" ]; then
	echo "using standard host path"
	exit 0
fi

TARGET_DIR="$CLUSTER_BASE/$USER_NAME/inception-storage"
echo "==> [cluster detected] configuring storage in $TARGET_DIR..."

mkdir -p "$TARGET_DIR/VirtualBoxVMs"
mkdir -p "$TARGET_DIR/vagrant.d"
mkdir -p "$TARGET_DIR/packer_cache"

if command -v VBoxManage >/dev/null 2>&1; then
	CURRENT_VBOX=$(VBoxManage list systemproperties 2>/dev/null | grep "Default machine folder" | awk -F: '{print $2}' | xargs || true)
	if [ "$CURRENT_VBOX" != "$TARGET_DIR/VirtualBoxVMs" ]; then
		echo "-> setting VirualBox machinefolder to $TARGET_DIR/VirtualBoxVMs"
		VBoxManage setproperty machinefolder "$TARGET_DIR/VirtualBoxVMs"
	fi
fi

if [ ! -L "$HOME/.vagrant.d" ] || [ "$(readlink "$HOME/.vagrant.d")" != "$TARGET_DIR/vagrant.d" ]; then
	echo "-> redirecting ~/.vagrant.d to $TARGET_DIR/vagrant.d"
	rm -rf "$HOME/.vagrant.d"
	ln -sfn "$TARGET_DIR/vagrant.d" "$HOME/.vagrant.d"
fi

mkdir -p "$HOME/.cache"
if [ ! -L "$HOME/.cache/packer" ] || [ "$(readlink "$HOME/.cache/packer")" != "$TARGET_DIR/packer_cache" ]; then
	echo "-> redirecting ~/.cache/packer to $TARGET_DIR/packer_cache"
	rm -rf "$HOME/.cache/packer"
	ln -sfn "$TARGET_DIR/packer_cache" "$HOME/.cache/packer"
fi

if [ ! -L "$HOME/VirtualBox VMs" ] || [ "$(readlink "$HOME/VirtualBox VMs")" != "$TARGET_DIR/VirtualBoxVMs" ]; then
	rm -rf "$HOME/VirtualBox VMs"
	ln -sfn "$TARGET_DIR/VirtualBoxVMs" "$HOME/VirtualBox VMs"
fi

echo "==> [cluster] NFS cluster disk is protecred"