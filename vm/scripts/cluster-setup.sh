#!/bin/sh

set -eu

USER_NAME="${USER:-$(whoami)}"

CLUSTER_BASE=""
if [ -d "/goinfre" ]; then
	CLUSTER_BASE="/goinfre"
fi

if [ -z "$CLUSTER_BASE" ]; then
	echo "using standard host path"
	exit 0
fi

TARGET_DIR="$CLUSTER_BASE/$USER_NAME/inception-storage"

if [ ! -w "$CLUSTER_BASE" ] && [ ! -d "$CLUSTER_BASE/$USER_NAME" ]; then
	echo "[WARNING] $CLUSTER_BASE is not writable by $USER_NAME. Falling back to standard paths."
	exit 0
fi

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

safe_link() {
	src="$1"
	dst="$2"

	if [ -L "$src" ] && [ "$(readlink "$src")" = "$dst" ]; then
		return 0
	fi

	if [ -d "$src" ] && [ ! -L "$src" ]; then
		if [ -n "$(ls -A "$src" 2>/dev/null)" ]; then
			echo "-> migrating existing data from $src to $dst..."
			cp -a "$src/." "$dst/" && rm -rf "$src" || { echo "[ERROR] could not migrate $src to $dst, original preserved" >&2; exit 1; }
		else
			rm -rf "$src"
		fi
	elif [ -L "$src" ]; then
		rm -f "$src"
	fi

	ln -sfn "$dst" "$src"
}

echo "-> safely redirecting cache and VM folders to /goinfre..."
safe_link "$HOME/.vagrant.d" "$TARGET_DIR/vagrant.d"
mkdir -p "$HOME/.cache"
safe_link "$HOME/.cache/packer" "$TARGET_DIR/packer_cache"
safe_link "$HOME/VirtualBox VMs" "$TARGET_DIR/VirtualBoxVMs"

echo "==> [cluster] NFS cluster disk is protecred"