#!/bin/sh
# provision.sh - Configures Docker, users, networking, and SSH inside the Inception VM

set -eu

# Ensure script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: this script must run as root." >&2
    exit 1
fi

LOGIN="${LOGIN:-alcacere}"

# Validate the username
case "$LOGIN" in
    ''|[!a-z_]*|*[!a-z0-9_-]*)
        echo "ERROR: Invalid username: $LOGIN" >&2
        exit 1
        ;;
esac

echo "==> Setting up Vagrant insecure SSH key..."
VAGRANT_KEY_URL="https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub"
TMP_KEY="/tmp/vagrant.pub.$$"

curl -fsSL "$VAGRANT_KEY_URL" -o "$TMP_KEY"
if [ ! -s "$TMP_KEY" ]; then
    echo "ERROR: Could not download Vagrant public key." >&2
    exit 1
fi

install_vagrant_key() {
    TARGET_USER="$1"
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    SSH_DIR="$TARGET_HOME/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    install -d -m 0700 -o "$TARGET_USER" -g "$TARGET_USER" "$SSH_DIR"
    touch "$AUTH_KEYS"

    while IFS= read -r key; do
        if [ -n "$key" ] && ! grep -qF "$key" "$AUTH_KEYS"; then
            printf '%s\n' "$key" >> "$AUTH_KEYS"
        fi
    done < "$TMP_KEY"

    chown "$TARGET_USER:$TARGET_USER" "$AUTH_KEYS"
    chmod 0600 "$AUTH_KEYS"
}

# Install key for vagrant user
install_vagrant_key vagrant
rm -f "$TMP_KEY"

echo "==> Removing conflicting packages if present..."
PACKAGES_TO_REMOVE=""
for pkg in docker.io docker-doc docker-compose docker-buildx podman-docker containerd runc; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        PACKAGES_TO_REMOVE="$PACKAGES_TO_REMOVE $pkg"
    fi
done

if [ -n "$PACKAGES_TO_REMOVE" ]; then
    apt-get remove -y $PACKAGES_TO_REMOVE
fi

echo "==> Installing prerequisites for Docker repository..."
apt-get update
apt-get install -y ca-certificates curl

echo "==> Adding Docker official GPG key and repository..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
ARCH=$(dpkg --print-architecture)

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $VERSION_CODENAME
Components: stable
Architectures: $ARCH
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "==> Installing Docker Engine and Compose plugin..."
apt-get update
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "==> Configuring Docker log rotation..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF

echo "==> Enabling and starting Docker service..."
systemctl daemon-reload
systemctl enable --now docker

echo "==> Creating login user ($LOGIN)..."
if ! getent passwd "$LOGIN" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$LOGIN"
fi

usermod -aG sudo,docker "$LOGIN"

# Configure passwordless sudo for LOGIN user
echo "$LOGIN ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$LOGIN"
chmod 0440 "/etc/sudoers.d/$LOGIN"
visudo -cf "/etc/sudoers.d/$LOGIN"

echo "==> Configuring domain in /etc/hosts..."
DOMAIN="${LOGIN}.42.fr"
if ! grep -qF "$DOMAIN" /etc/hosts; then
    printf '127.0.0.1 %s\n' "$DOMAIN" >> /etc/hosts
fi

echo "==> Configuring SSH service..."
mkdir -p /etc/ssh/sshd_config.d
# sshd keeps the first value it reads, and files load in name order: 00- makes these win.
cat > /etc/ssh/sshd_config.d/00-inception.conf <<EOF
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF

sshd -t
# Do not reload ssh here: Packer still logs in with the password until the build ends.
# These settings apply from the next boot, which is the first boot of the finished box.
systemctl enable ssh

echo "==> Provisioning completed successfully!"
