# User & Administrator Guide

Welcome to the **Inception** service infrastructure for `alcacere.42.fr`. This guide explains how to start, stop, access, and maintain the stack as an administrator or evaluator.

---

## 1. Services Overview

| Service | Description | URL / Access Point | Authentication |
| :--- | :--- | :--- | :--- |
| **WordPress** | Personal blogging CMS and publishing platform | `https://alcacere.42.fr/` | Public read access |
| **WordPress Admin** | WP Dashboard & site administration | `https://alcacere.42.fr/wp-admin/` | Admin user & password from secrets |
| **Adminer** | Database administration web interface | `https://alcacere.42.fr/adminer` | MariaDB credentials from secrets |
| **Static Website** | Developer portfolio & interactive arcade game | `https://alcacere.42.fr/portfolio/` | Public access |
| **Prometheus** | Metric collection and alert monitoring | `https://alcacere.42.fr/prometheus/` | Prometheus dashboard |
| **FTP (vsftpd)** | Direct file transfer to WordPress webroot | `ftp://alcacere.42.fr:21` | FTP user & password from secrets |
| **Redis** | Object caching engine | Internal (`redis:6379`) | Internal password |
| **MariaDB** | SQL database engine | Internal (`mariadb:3306`) | Database password |

---

## 2. Managing the Service Lifecycle

All lifecycle operations are controlled from the repository root using `make`:

```bash
# Start all containers in the background (builds images if needed)
make

# Check health and status of all services
make ps

# Inspect real-time logs across all services
make logs

# Stop all services without deleting any data
make down

# Temporarily pause / resume running containers
make stop
make start

# Full teardown: removes containers, networks, and persistent data volumes
make fclean
```

---

## 3. Accessing the Website & Admin Panel

### Domain Configuration
Because this infrastructure is hosted locally, your operating system must know how to route `alcacere.42.fr` to the server IP:

* If working **inside the VM**:
  ```bash
  echo "127.0.0.1 alcacere.42.fr" | sudo tee -a /etc/hosts
  ```
* If testing **from your host computer** connecting to the VirtualBox VM:
  ```bash
  echo "192.168.56.42 alcacere.42.fr" | sudo tee -a /etc/hosts
  ```

### SSL / TLS Certificate
All web traffic is encrypted with **TLS 1.2 and TLS 1.3**.
When connecting for the first time in an external web browser, you may see a self-signed certificate warning. This is expected in development environments. Simply click **Advanced** $\rightarrow$ **Accept the Risk and Continue**.

*(Inside the provided automated Debian VM, the local Root CA is pre-installed into the Firefox trust database, so Firefox displays a secure green padlock with zero warnings).*

### Admin Login
* Navigate to `https://alcacere.42.fr/wp-admin/`.
* Enter the credentials defined in your secrets files (see Section 4 below).

---

## 4. Credentials & Password Management

All credentials follow the **principle of least privilege** and are separated into two distinct locations:

1. **Non-secret configuration** is stored in [srcs/.env.example](srcs/.env.example) (copied to `srcs/.env` during initial setup):
   * `DOMAIN_NAME`: `alcacere.42.fr`
   * `MYSQL_DATABASE`: `wordpress`
   * `MYSQL_USER`: `wp_dbuser`
   * `WP_ADMIN_USER`: `alcacere`
   * `WP_USER`: `wp_author`
   * `FTP_USER`: `ftp_user`

2. **Sensitive passwords** are stored in individual files inside the `secrets/` directory (git-ignored, `0600` permissions):
   * `secrets/db_root_password.txt`: MariaDB root administrative password.
   * `secrets/db_password.txt`: MariaDB user password for WordPress.
   * `secrets/wp_admin_password.txt`: WordPress Administrator account password.
   * `secrets/wp_user_password.txt`: Regular WordPress author account password.
   * `secrets/redis_password.txt`: Redis object cache connection password.
   * `secrets/ftp_password.txt`: FTP user password.

> [!IMPORTANT]
> **Changing Passwords After Initial Startup:**
> MariaDB and WordPress store accounts inside the persistent database tables during their initial setup. If you modify any password in `secrets/*.txt` after the database has already been created, the stack will be unable to authenticate against the old database. To apply new passwords, you must run `make fclean` to clean the old database and initialize a fresh stack with `make`.

---

## 5. Health Checks & Verification

To verify that the entire infrastructure is operating normally:

### 1. Check Container Health
Run `make ps`. Every container must display the status `healthy`:

```text
NAME         IMAGE                  STATUS
mariadb      mariadb:inception      Up (healthy)
wordpress    wordpress:inception    Up (healthy)
nginx        nginx:inception        Up (healthy)
redis        redis:inception        Up (healthy)
adminer      adminer:inception      Up (healthy)
website      website:inception      Up (healthy)
ftp          ftp:inception          Up (healthy)
blackbox     blackbox:inception     Up (healthy)
prometheus   prometheus:inception   Up (healthy)
```

### 2. Verify Port 80 is Closed
The subject requires that the server strictly refuses plain HTTP connections on port 80. You can test this using `curl`:

```bash
curl -I http://alcacere.42.fr/
# Output: Failed to connect / Connection refused (Expected)
```

### 3. Verify Redis Cache in WordPress
Execute WP-CLI inside the WordPress container to verify that object caching is actively connected:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress wp redis status --path=/var/www/html --allow-root
# Status: Connected
# Drop-in: Valid
```

### 4. Test FTP File Upload
Connect to the FTP server using curl or your preferred FTP client:

```bash
curl -u ftp_user:$(cat secrets/ftp_password.txt) ftp://alcacere.42.fr/
# Outputs the WordPress directory file tree
```
