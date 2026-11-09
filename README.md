*This project has been created as part of the 42 curriculum by alcacere.*

# Description

Inception is a system administration and DevOps project designed to build a complete, production-grade microservice infrastructure using **Docker** and **Docker Compose** inside a dedicated virtual machine running Debian.

The goal of this project is to orchestrate multiple containers, ensuring strict network isolation, automated initialization, security hardening, and persistent storage without using pre-built "all-in-one" images or deprecated Docker features.

### Architecture Overview

```text
Host / Browser (VirtualBox VM or Workstation)
   │
   │  HTTPS (Port 443 only)
   ▼
┌────────────────────────────────────────────────────────────────────────┐
│  NGINX Reverse Proxy (Alpine 3.23)                                     │
│  TLS 1.2 / 1.3  •  Custom 2-Tier PKI Certificate                       │
└────┬──────────────────┬───────────────────┬───────────────────┬────────┘
     │ FastCGI (9000)   │ FastCGI (9000)    │ HTTP (8080)       │ HTTP (9090)
     ▼                  ▼                   ▼                   ▼
┌──────────────┐  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  WordPress   │  │   Adminer    │    │Static Website│    │  Prometheus  │
│  (PHP-FPM)   │  │ (DB Manager) │    │  Portfolio   │    │  (Metrics)   │
└──────┬───────┘  └──────┬───────┘    └──────────────┘    └──────┬───────┘
       │ SQL (3306)      │ SQL (3306)                            │ Scrapes
       ▼                 ▼                                       ▼
┌──────────────┐  ┌──────────────┐                        ┌──────────────┐
│   MariaDB    │  │ Redis Cache  │◄── Object Cache        │   Blackbox   │
│  (Database)  │  │ (Port 6379)  │    (WordPress)         │   Exporter   │
└──────────────┘  └──────────────┘                        └──────────────┘
       ▲
       │ File Sync (/var/www/html)
┌──────────────┐
│  FTP Server  │ (Ports 21 & 21000-21010)
│   (vsftpd)   │
└──────────────┘
```

---

# Instructions

### 1. Prerequisites
* **Operating System**: Linux (Debian/Ubuntu recommended) or the provided Vagrant VM.
* **Dependencies**: `make`, `docker`, `docker compose`, `openssl`, `curl`.
* **Domain Name Resolution**: Add `alcacere.42.fr` to your `/etc/hosts`:
  ```bash
  echo "127.0.0.1 alcacere.42.fr" | sudo tee -a /etc/hosts
  ```
  *(If testing from outside the VM, replace `127.0.0.1` with the VM's static IP `192.168.56.42`).*

### 2. Quick Start
From the project root directory:

```bash
# 1. Build and start all services in detached mode
make

# 2. Check the status of all running containers
make ps

# 3. Follow live logs across all containers
make logs

# 4. Stop containers without deleting data
make down

# 5. Clean everything (containers, networks, volumes, and persistent data)
make fclean
```

### 3. Service Access Points

| Service | Protocol / Port | Access URL |
| :--- | :--- | :--- |
| **WordPress Web** | HTTPS / 443 | `https://alcacere.42.fr` |
| **WordPress Admin** | HTTPS / 443 | `https://alcacere.42.fr/wp-admin` |
| **Adminer** | HTTPS / 443 | `https://alcacere.42.fr/adminer` |
| **Static Portfolio + Game** | HTTPS / 443 | `https://alcacere.42.fr/portfolio/` |
| **Prometheus Monitoring** | HTTPS / 443 | `https://alcacere.42.fr/prometheus/` |
| **FTP Server** | FTP / 21 & 21000-21010 | `ftp://alcacere.42.fr` |

---

# Resources

### References
* [Docker Official Documentation](https://docs.docker.com/)
* [Docker Compose Specification](https://docs.docker.com/compose/)
* [Alpine Linux Package Repository](https://pkgs.alpinelinux.org/)
* [NGINX Documentation](https://nginx.org/en/docs/)
* [MariaDB Server Knowledge Base](https://mariadb.com/kb/en/)
* [WordPress Developer Resources & WP-CLI](https://developer.wordpress.org/)
* [Redis Documentation](https://redis.io/docs/)
* [vsftpd Configuration Reference](https://security.appspot.com/vsftpd/vsftpd_conf.html)
* [Prometheus & Blackbox Exporter Docs](https://prometheus.io/docs/)
* [HTML5 Canvas Snake Game](https://github.com/) (Open-source MIT reference customized for the portfolio)

### Use of Artificial Intelligence
Artificial Intelligence was utilized strictly as an advisory assistant throughout this project. It was used to help structure project documentation, understand Linux system administration concepts (such as Mozilla PKIX certificate constraints and Docker networking), and debug configuration edge cases. The architecture design, file authoring, implementation choices, and verification were performed and validated directly by the student.

---

# Project Description

### Container Architecture & Sources
All services are containerized individually using lightweight **Alpine Linux 3.23** base images and organized under `srcs/requirements/`:

* `srcs/requirements/mariadb`: Relational database storing WordPress tables. Initialized securely via SQL bootstrapping without plaintext credentials in command arguments.
* `srcs/requirements/wordpress`: PHP-FPM 8.4 engine running WordPress. Features headless automated setup via WP-CLI with FastCGI protocol.
* `srcs/requirements/nginx`: The single web entry point. Enforces TLS 1.2 and TLS 1.3, terminates SSL, and reverse-proxies HTTP and FastCGI backends.
* `srcs/requirements/bonus/redis`: In-memory object cache with an LRU eviction policy, directly integrated into WordPress via `redis-cache`.
* `srcs/requirements/bonus/adminer`: Standalone PHP database management interface for MariaDB with zero exposed host ports.
* `srcs/requirements/bonus/website`: Static showcase portfolio featuring an interactive HTML5 Canvas Snake arcade game, served with `darkhttpd`.
* `srcs/requirements/bonus/ftp`: Very Secure FTP Daemon (`vsftpd`) providing chrooted access to `/var/www/html` with unified UID 1000 ownership.
* `srcs/requirements/bonus/prometheus` & `blackbox`: SOC-style external network probe and time-series monitoring, scraping HTTP, TLS certificates, MariaDB, Redis, and FTP without requiring privileged host sockets.

---

### Key Comparisons

## Virtual Machines vs Docker

* **Virtual Machines (VMs)**:
  Virtual Machines run on top of a hypervisor (e.g., VirtualBox, KVM). Each VM runs a completely separate guest operating system with its own kernel, device drivers, and dedicated virtual memory. This provides strong hardware-level isolation, but incurs heavy resource overhead, slower boot times (seconds to minutes), and large disk footprints (gigabytes per VM).
* **Docker Containers**:
  Containers are isolated user-space processes running directly on the host Linux kernel using kernel primitives: **namespaces** (for process, mount, network, and user isolation) and **cgroups** (control groups for CPU, RAM, and I/O resource limiting). Because they share the host kernel, containers start almost instantaneously, consume minimal RAM, and require significantly less storage.

## Secrets vs Environment Variables

* **Environment Variables**:
  Stored in process memory tables (`/proc/<pid>/environ`). They are inherited by all child processes, visible in `docker inspect <container>`, visible in `docker compose ps` / process lists, and frequently printed in debugging traces or crash logs. They are ideal for non-sensitive configuration (e.g., `DOMAIN_NAME`, `REDIS_PORT`).
* **Docker Secrets**:
  Secrets are mounted in-memory as read-only files under `/run/secrets/<secret_name>` with restricted permissions (e.g., `0400` or `0440`). They are never recorded in container image layers, do not show up in `docker inspect`, and are not inherited by child process environments, making them the industry standard for managing passwords, database credentials, and cryptographic keys.

## Docker Network vs Host Network

* **Host Network (`--net=host`)**:
  The container shares the network namespace of the host machine directly. Container processes bind directly to the host's network interfaces with no port mapping or network isolation. A security breach in the container directly exposes the host network, and port collisions occur if two containers use the same port.
* **User-Defined Bridge Network (Docker Network)**:
  Containers are attached to an isolated software bridge (`inception`) with their own private IP subnet, virtual interfaces (`veth`), and iptables firewall rules. Docker provides an embedded DNS resolver (`127.0.0.11`) that enables safe inter-container service discovery by container name without exposing internal ports to the host machine or public internet.

## Docker Volumes vs Bind Mounts

* **Bind Mounts**:
  Mount a specific path from the host filesystem directly into the container (e.g., `${DATA_PATH}/wordpress:/var/www/html`). The container process accesses host directories directly based on the host's UID/GID permissions. This makes files immediately accessible on the host, but depends on the host's directory structure and permission model.
* **Named Volumes**:
  Managed entirely by the Docker daemon under its private storage path (`/var/lib/docker/volumes/`). They abstract the underlying storage, allow Docker to manage data lifecycles independently of container lifecycles, and remain portable across different host operating systems. In this project, named volumes backed by local bind driver options combine the convenience of host persistence in `/home/alcacere/data/` with the isolation guarantees of named volume tracking.
