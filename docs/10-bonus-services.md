# 10 — Bonus services (and suggestions)

> ☠ The bonus is **ignored** unless the mandatory part is perfect. Build and
> test the mandatory part first, commit, then add bonus services one by one.

Subject rules for each bonus service: its **own Dockerfile**, its **own container**,
and **its own volume if needed**. Extra ports may be opened.

**Design suggestion to stand out:** keep **443 the only web entry point** even for
bonus UIs. NGINX reverse-proxies `/adminer/`, `/portfolio/` (or a subdomain),
`/prometheus/` over TLS. The only extra published ports are then FTP (21 + the passive
range), because FTP can't go through an HTTP proxy. It's a strong design argument in the defense.

---

## 1. Redis (cache for WordPress)

**What?** An in-memory key-value store. Here it's used as WordPress's **object
cache**: results of expensive DB queries / computed objects are stored in RAM,
so repeated page loads hit Redis instead of MariaDB.

**How it plugs in**
- WordPress has an object-cache API (`WP_Object_Cache`). By default it only lives for
  one request. A **drop-in** `wp-content/object-cache.php` makes it persistent.
- The **Redis Object Cache** plugin provides this drop-in: `wp plugin install redis-cache --activate`
  then `wp redis enable`. Config constants in `wp-config.php`: `WP_REDIS_HOST=redis`,
  `WP_REDIS_PORT=6379`, `WP_REDIS_PASSWORD` (from a secret).
- Container: `apk add redis`, `redis-server /etc/redis.conf` in the foreground.

**Config you'll write** (`redis.conf`): `bind 0.0.0.0`, `protected-mode yes` +
`requirepass` (from a secret), `maxmemory 128mb`, `maxmemory-policy allkeys-lru`
(evict the least recently used keys when full: that's what a cache does), and
persistence off (`save ""`, `appendonly no`). It's a cache, so losing it is fine and
**no volume** is needed. Justify that!

**Demo:** `wp redis status` (Connected) · `docker exec -it redis redis-cli -a <pw> monitor`
while browsing the site · `redis-cli INFO stats | grep keyspace` (hits/misses) ·
the WordPress dashboard → Settings → Redis.

**Docs**
- Redis docs: <https://redis.io/docs/latest/>
- Configuration: <https://redis.io/docs/latest/operate/oss_and_stack/management/config/>
- Eviction policies: <https://redis.io/docs/latest/develop/reference/eviction/>
- Security (`requirepass`, protected mode): <https://redis.io/docs/latest/operate/oss_and_stack/management/security/>
- Plugin: <https://wordpress.org/plugins/redis-cache/>
- WP object cache: <https://developer.wordpress.org/reference/classes/wp_object_cache/>

---

## 2. FTP server (vsftpd) pointing to the WordPress volume

**What?** **FTP** (File Transfer Protocol, RFC 959) transfers files using **two
connections**: a *control* connection (port 21, commands) and a *data* connection
per transfer. In **passive mode** the server opens a port from a range and tells
the client "connect to IP:port". **vsftpd** ("Very Secure FTP Daemon") is a minimal, hardened FTP server.

**Why?** Lets a user upload themes/plugins/media directly into the WordPress files
volume, which is the classic hosting workflow.

**Config you'll write** (`vsftpd.conf`): `listen=YES`, `background=NO` (PID 1!),
`anonymous_enable=NO`, `local_enable=YES`, `write_enable=YES`,
`chroot_local_user=YES` + `allow_writeable_chroot=YES` (the user is jailed in the WP dir),
`local_root=/var/www/html`, `pasv_enable=YES`, `pasv_min_port=21000`,
`pasv_max_port=21010`, `pasv_address=<IP the client uses>`, and often
`seccomp_sandbox=NO` inside containers.

**Pitfalls**
- **Passive mode behind Docker NAT**: the server announces its *container* IP
  (172.x / 10.x) unless you set `pasv_address`. The client then can't connect and
  `ls` hangs. Publish the passive range in compose (`21000-21010:21000-21010`).
- The FTP user must have the **same UID** as the files' owner (php-fpm user) or uploads
  will be read-only for WordPress.
- The password comes from a secret: `echo "user:$(cat /run/secrets/ftp_password)" | chpasswd`.
- Optional "outstanding": FTPS (`ssl_enable=YES`, `ssl_tlsv1_2=YES`), because FTP
  sends passwords in clear text. Mentioning this shows you understand the protocol.

**Demo:** `lftp -u user alcacere.42.fr` or `curl -u user:pw ftp://alcacere.42.fr/`,
upload a file and show it in `/home/alcacere/data/wordpress`.

**Docs**
- vsftpd: <https://security.appspot.com/vsftpd.html>
- `vsftpd.conf` man page: <https://security.appspot.com/vsftpd/vsftpd_conf.html>
- RFC 959: <https://datatracker.ietf.org/doc/html/rfc959>
- Active vs passive FTP: <https://slacksite.com/other/ftp.html>

---

## 3. Static website (any language except PHP)

**What?** A site made only of files (HTML/CSS/JS) served as-is, with no server-side code.

**Ideas for content:** your CV/portfolio, or (more useful) an **"Inception status
page"** that explains your architecture with a diagram and links to each service.

**How to serve it:** the smallest valid option is **BusyBox httpd**, which is already in
`alpine:3.23`, so you install nothing: `busybox httpd -f -p 8080 -h /www`
(`-f` = foreground → PID 1). Alternatives: `lighttpd` (the reference),
`darkhttpd`, or a site **generated** at build time with a tool in another language
(e.g. Hugo/Go: build in a first stage, copy the HTML into the final image with a
**multi-stage build**, which is a nice thing to explain).

**Expose it:** NGINX `location /portfolio/ { proxy_pass http://website:8080/; }`.

**Docs**
- BusyBox httpd options: <https://busybox.net/downloads/BusyBox.html#httpd>
- Multi-stage builds: <https://docs.docker.com/build/building/multi-stage/>
- MDN HTML/CSS: <https://developer.mozilla.org/en-US/docs/Learn_web_development>

---

## 4. Adminer

**What?** A single-file **PHP** web UI to manage databases (like phpMyAdmin but one file).
PHP is allowed here (only the static site excludes PHP).

**How:** its own container with `php84-fpm` + `php84-mysqli` + `php84-session`, download
`adminer-<version>.php` from the official releases and **verify its sha256**.
NGINX routes `/adminer` with `fastcgi_pass adminer:9000` and
`SCRIPT_FILENAME /var/www/adminer/index.php` (the path inside the Adminer container).
Login: server `mariadb`, user `wp_user`, password from the secret.

**Security note for the defense:** a DB admin UI is sensitive. Put it behind TLS
(through NGINX) and optionally `auth_basic`, and never publish it directly on a port.

**Docs**
- Adminer: <https://www.adminer.org/>
- Releases: <https://github.com/vrana/adminer/releases>

---

## 5. Free choice: Prometheus + Blackbox Exporter (monitoring)

**What?**
- **Blackbox Exporter** tests services **from the outside, over the network**, like a client: "does
  this HTTPS URL answer? which TLS version? when does the certificate expire? is this TCP port open?"
  It publishes the answers as metrics.
- **Prometheus** is a time-series database + scraper. It pulls `/metrics` endpoints on a schedule,
  stores the samples, and lets you query them with **PromQL**.

**Why this and not cAdvisor?** cAdvisor reads per-container stats from the host, so its upstream setup
mounts the VM's disk and `docker.sock`. `:ro` doesn't stop API calls through a socket, which makes it
effectively root on the VM. Blackbox needs **no mounts, no capabilities, no root**. Tested with
`cap_drop: ALL`, `no-new-privileges`, a read-only root filesystem and a non-root user.

**The trade-off:** you lose per-container CPU and RAM history. For those, use `docker stats` by hand.
Say it plainly in the defense: you gave up detail to avoid host access.

**Why is it useful? (your defense argument)**
It continuously checks the subject's security rules, not just "is it up":

| Probe | Tested result | Meaning |
|---|---|---|
| `https://alcacere.42.fr` | `probe_success 1`, `probe_tls_version_info{version="TLS 1.3"}` | Site up, TLS version visible |
| Same, forcing TLS 1.1 | `probe_success 0` | Old TLS refused |
| TCP to `nginx:443` | `probe_success 1` | Entry point open |
| TCP to `nginx:80` | `probe_success 0` | Port 80 closed: alert if it opens |
| Certificate | `probe_ssl_earliest_cert_expiry` | Alert before it expires |

These were tested on a local self-signed NGINX, not your final stack. Strict verification fails on a
self-signed certificate, as expected: give the exporter your certificate as CA, or use
`insecure_skip_verify` and state it.

**Architecture**
```
Blackbox ──probes over the network──► nginx, mariadb:3306, redis, ...
   ▲ /probe?target=...&module=...   (never published)
Prometheus ──also scrapes──► itself
   ▲
NGINX https://alcacere.42.fr/prometheus/  (TLS + auth_basic)
```

**How to build on Alpine 3.23**
- Blackbox: `apk add prometheus-blackbox-exporter`. The binary is `blackbox_exporter`, port 9115.
- Prometheus: `apk add prometheus`.

Run: `prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus
--web.external-url=https://alcacere.42.fr/prometheus/ --web.route-prefix=/`

**The scrape config needs relabeling**, because the target goes in a URL parameter and the scrape goes
to the exporter. See the official example linked below.

**PromQL for the demo**
```
probe_success
probe_tls_version_info
(probe_ssl_earliest_cert_expiry - time()) / 86400     # days left
```

**Docs**
- Prometheus overview: <https://prometheus.io/docs/introduction/overview/>
- Configuration: <https://prometheus.io/docs/prometheus/latest/configuration/configuration/>
- Alerting rules: <https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/>
- PromQL: <https://prometheus.io/docs/prometheus/latest/querying/basics/>
- Security model: <https://prometheus.io/docs/operating/security/>
- Blackbox Exporter: <https://github.com/prometheus/blackbox_exporter>
- Blackbox config: <https://github.com/prometheus/blackbox_exporter/blob/master/CONFIGURATION.md>

### How dangerous are the other observability tools?

| Tool | Host access | Risk | Notes |
|---|---|---|---|
| **Blackbox Exporter** | None | Low | Can request any URL it's told to, so **never publish port 9115** |
| **Prometheus** | None | Low | No auth by default, so keep it behind NGINX + `auth_basic`. Admin API is off by default |
| **GoAccess** | None (reads a log volume) | Low | Parses attacker-controlled logs, and is what the reference uses |
| **Grafana** | None | Low-medium | Adds a login page and more software to patch |
| **Uptime Kuma** | None unless given the socket | Low-medium | Don't give it the socket |
| **Docker engine metrics** | Opens a path to the VM | Medium | Unauthenticated, engine-level only, and containers must reach the VM |
| **node-exporter** | `/proc`, `/sys`, often the root disk | Medium | Avoid the root mount |
| **Promtail / Alloy with Docker logs** | Socket or `/var/lib/docker` | High | Same issue as cAdvisor |
| **cAdvisor** | Disk + socket | High | Replaced |
| **Portainer** | Socket, and it's built to control Docker | Critical | Avoid |

Rule of thumb: **anything mounting `docker.sock` or the host's root is equal to root on the VM.**

---

## Other free-choice ideas (if you ever want to change or add)

| Service | Why it's useful | Effort | Notes |
|---------|-----------------|--------|-------|
| **Backup container** (cron + `mariadb-dump` + tar of WP files, rotation) | Disaster recovery. Ties into the eval's "Persistence" section | Low | `crond -f` is a real foreground daemon (allowed) |
| **Mailpit** | WordPress sends emails (password reset, new comment). Mailpit catches them in a web UI | Low/Med | Go binary. Configure WP SMTP |
| **Uptime Kuma** | Status page that monitors every service (HTTPS, TCP 3306, FTP) | Medium | Node.js, build from source |
| **Grafana** | Dashboards on top of Prometheus | Medium | Pairs with your choice, adds a login page |
| **GoAccess** | Real-time NGINX access-log analytics | Low | Already in the reference, so avoid copying |
| **Portainer** | Docker GUI | Low | ⚠ needs `/var/run/docker.sock` = root on the VM. Hard to justify security-wise |
