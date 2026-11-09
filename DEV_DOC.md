# Developer & Architecture Guide

This document describes the internal engineering, directory layout, automated build processes, and maintenance procedures for developers modifying or extending the **Inception** infrastructure.

---

## 1. Environment Setup from Scratch

### Prerequisites
* **Operating System**: Linux (Debian 13 recommended) or macOS.
* **Virtualization & Automation**: VirtualBox, HashiCorp Packer (for automated OS preseed install), and HashiCorp Vagrant.
* **Container Tooling**: Docker Engine 24+ and Docker Compose v2.

### Automated VM Provisioning
The repository includes complete Infrastructure as Code (IaC) to create a reproducible Debian 13 VM:

```bash
# 1. Automatically configure VirtualBox storage in /goinfre (42 Cluster)
make cluster

# 2. Build the base Debian 13 box with Packer (unattended netinst preseed)
make vm-box

# 3. Boot and provision the Vagrant VM
make vm

# 4. Open an SSH session into the VM
make vm-ssh
```

### Configuration & Secret Generation
On initial setup, running `make` automatically executes [srcs/requirements/tools/generate-secrets.sh](file:///home/alcacere/inception/alcacere_inception/srcs/requirements/tools/generate-secrets.sh), which:
1. Copies `srcs/.env.example` to `srcs/.env` if not present.
2. Generates cryptographically secure 24-character random passwords in `secrets/*.txt`:

| Secret File | Consuming Service | Purpose |
| :--- | :--- | :--- |
| `secrets/db_root_password.txt` | MariaDB | Administrative root password for initial database bootstrapping |
| `secrets/db_password.txt` | MariaDB, WordPress | Database authentication password for `wp_dbuser` |
| `secrets/wp_admin_password.txt` | WordPress | Administrator account (`alcacere`) password |
| `secrets/wp_user_password.txt` | WordPress | Regular author account (`wp_author`) password |
| `secrets/redis_password.txt` | Redis, WordPress | Redis `requirepass` authentication |
| `secrets/ftp_password.txt` | FTP (`vsftpd`) | Linux user password for `ftp_user` |

---

## 2. Directory Structure

```text
.
├── Makefile                           # Root build automation & lifecycle targets
├── README.md                          # Mandatory project overview & comparisons
├── USER_DOC.md                        # Administrator & end-user handbook
├── DEV_DOC.md                         # Developer technical documentation
├── secrets/                           # Secret password store (0600 permissions, git-ignored)
├── srcs/
│   ├── .env                           # Non-secret environment configuration
│   ├── .env.example                   # Template environment configuration
│   ├── docker-compose.yml             # Service composition and network topology
│   └── requirements/
│       ├── mariadb/
│       │   ├── conf/mariadb-server.cnf  # MariaDB configuration (buffer pool, networking)
│       │   ├── tools/entrypoint.sh      # Idempotent DB boot & user initialization
│       │   └── Dockerfile               # Alpine 3.23 + mariadb
│       ├── wordpress/
│       │   ├── conf/www.conf            # PHP-FPM pool config (user www, port 9000)
│       │   ├── tools/entrypoint.sh      # Automated WP-CLI installation & Redis plugin
│       │   └── Dockerfile               # Alpine 3.23 + php84-fpm + wp-cli
│       ├── nginx/
│       │   ├── conf/inception.conf.template # TLS reverse proxy configuration template
│       │   ├── tools/entrypoint.sh      # 2-Tier PKI certificate generator & envsubst
│       │   └── Dockerfile               # Alpine 3.23 + nginx + openssl
│       ├── tools/
│       │   ├── check-env.sh             # Validates required environment variables
│       │   └── generate-secrets.sh      # Auto-generates missing secrets safely
│       └── bonus/
│           ├── adminer/                 # Single-file database management UI
│           ├── blackbox/                # External TCP and HTTPS metric probe
│           ├── ftp/                     # Very Secure FTP daemon (vsftpd)
│           ├── prometheus/              # Prometheus metric scraper & alert rules
│           ├── redis/                   # In-memory Redis object cache
│           └── website/                 # Portfolio showcase + Snake (darkhttpd)
└── vm/                                # Packer and Vagrant VM automation scripts
```

---

## 3. Makefile Targets & Compose Automation

The root [Makefile](file:///home/alcacere/inception/alcacere_inception/Makefile) wraps all operations to prevent manual syntax errors:

| Make Target | Action Performed | Underlying Command |
| :--- | :--- | :--- |
| `make` / `make all` | Builds images, checks secrets, mounts volumes, and starts stack | `docker compose up -d --build` |
| `make build` | Builds or rebuilds all Docker images without starting | `docker compose build` |
| `make down` | Gracefully stops and removes containers and networks | `docker compose down` |
| `make stop` | Pauses running containers without removing them | `docker compose stop` |
| `make start` | Resumes paused containers | `docker compose start` |
| `make ps` | Displays container status, ports, and healthcheck results | `docker compose ps` |
| `make logs` | Streams interleaved real-time logs across all services | `docker compose logs -f` |
| `make clean` | Removes local containers and dangling images | `docker compose down --rmi local --remove-orphans` |
| `make fclean` | Complete purge: tears down stack and wipes `/home/alcacere/data/` | `docker compose down -v --rmi all` + `rm -rf $(DATA_DIR)` |
| `make re` | Re-executes a clean build from scratch | `make fclean && make all` |

---

## 4. Persistent Storage Architecture

All persistent data must survive container restarts, reboots, and `make down`. The subject requires storing all data inside `/home/alcacere/data`.

In [srcs/docker-compose.yml](file:///home/alcacere/inception/alcacere_inception/srcs/docker-compose.yml), this is achieved using **bind-backed named volumes**:

```yaml
volumes:
  mariadb:
    name: inception_mariadb
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_PATH}/mariadb

  wordpress:
    name: inception_wordpress
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_PATH}/wordpress

  certs:
    name: inception_certs
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_PATH}/certs

  prometheus:
    name: inception_prometheus
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_PATH}/prometheus
```

### Persistence Guarantees
* Running `make down` terminates containers and the virtual bridge network, but preserves named volumes and host disk files intact.
* Running `make fclean` deletes the containers and executes `sudo rm -rf $(DATA_DIR)/*`, wiping all data for a completely clean rebuild.

---

## 5. Security Model & Design Choices

### 1. Unified Ownership (UID 1000)
Both WordPress (PHP-FPM) and FTP (`vsftpd`) operate under a non-root system user named `www` with **UID 1000 and GID 1000**. This ensures:
* Files uploaded via FTP can be immediately read, executed, and overwritten by WordPress.
* Media uploaded through the WordPress web dashboard can be edited or deleted via FTP.
* Neither service runs as root or relies on global write permissions (`777`).

### 2. File Permission Hardening
WordPress directories and files are hardened on startup:
```sh
find /var/www/html -type d -exec chmod 755 {} +
find /var/www/html -type f -exec chmod 644 {} +
chmod 640 /var/www/html/wp-config.php
```
`wp-config.php` is restricted to `0640`, preventing unprivileged users on the host from reading database credentials.

### 3. Dynamic DNS & Bonus Isolation
In [inception.conf.template](file:///home/alcacere/inception/alcacere_inception/srcs/requirements/nginx/conf/inception.conf.template), bonus services are routed using runtime variables and Docker's internal DNS resolver:
```nginx
resolver 127.0.0.11 valid=10s ipv6=off;

location /portfolio/ {
    set $website_backend http://website:8080;
    rewrite ^/portfolio/(.*)$ /$1 break;
    proxy_pass $website_backend;
}
```
If a bonus container fails or is shut down, NGINX does not crash. It continues serving WordPress while returning `502 Bad Gateway` strictly for that specific bonus URL.

---

## 6. How to Add a New Service

To integrate an additional microservice into the Inception stack:

1. **Create the service directory**:
   ```bash
   mkdir -p srcs/requirements/bonus/<service_name>/conf
   mkdir -p srcs/requirements/bonus/<service_name>/tools
   ```
2. **Author the `Dockerfile`**:
   Use `alpine:3.23` as the base image. Create an unprivileged user and expose only the internal port.
3. **Register in `srcs/docker-compose.yml`**:
   Add the service block under `services:`. Attach it to the `inception` network. Define healthchecks with `CMD-SHELL`.
4. **Expose through NGINX** (if it provides a web UI):
   Add a `location /<service_name>/` block in `inception.conf.template` using the dynamic resolver pattern. **Do not publish container ports to the host.**
