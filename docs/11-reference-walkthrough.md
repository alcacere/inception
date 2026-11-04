# 11 — Walkthrough of `acaceres_inception` (what each thing is, and why)

Use this to **understand**, not to copy. For each file: what it does, the
non-obvious lines explained, and ✅ ideas worth reusing or ⚠ things to do differently.

---

## Root

### `Makefile`
- `COMPOSE = --file=... --env-file=srcs/.env` passes the compose file and the env file
  explicitly so `make` works from the repo root.
- `$(NAME): check_env` → `mkdir -p ~/data/{mariadb,wordpress}` → `up --detach --build`.
  The data dirs must exist **before** `up`, because the `local` driver with `o: bind` fails
  if the device path is missing.
- `DATA_DIR=$(DATA_DIR_NAME) docker compose ...` sets a shell env var for that single
  command. The shell env has priority over `.env` for interpolation, so `${DATA_DIR}`
  in the YAML becomes `/home/<user>/data`.
- `check_env` loops over `ENV_VARS` and greps `^VAR=` in `.env` to fail early with a
  clear message if a variable is missing or empty. It also checks that each secret file exists
  and has ≥ 8 bytes.
- `credentials` generates missing secrets with `openssl rand -hex 12` and copies
  `.example.env` to `.env`.
- `fclean`: `down --volumes --rmi all` + `rm -rf ~/data`.
- `$$var`, `$$file` are a doubled `$` so that **make** passes a literal `$` to the shell.
- ✅ Reuse: env/secret validation before starting, and a credentials generator.
- ⚠ `rm -rf ~/data` may fail with "Permission denied" because the files belong to container
  UIDs. You may need `sudo` or a `docker run --rm -v ...alpine rm -rf`.
- ⚠ It doesn't validate the admin username rule (no "admin"). You could add that.

### `.gitignore`
Ignores `srcs/.env` and `secrets/*` but keeps `secrets/.gitkeep` (`!` re-includes it;
Git doesn't track empty directories, so `.gitkeep` is a convention to keep the folder).

### `vm-module/Vagrantfile`
- `config.vm.box = "bento/debian-12"` is a **prebuilt** box (no OS installation step).
  We replace this with our own Packer-built box.
- `VM_EXISTS ? LOGIN : "vagrant"`: on the first `up` it SSHes as `vagrant` (the box
  contract), and later as the login user that provisioning created.
- `forwarded_port` maps host ports to VM ports (443→4443, etc.).
- `synced_folder ".", "/vagrant", disabled: true`: no shared folder (it uses a `copy.sh` script instead).
- The provisioner installs Docker from the official repo (same steps as docs.docker.com),
  adds the `/etc/hosts` entry and creates the login user.
- `/etc/.inception-system-provisioned` is a **marker file** that makes provisioning
  idempotent (`run: "always"` but it exits early).
- `grub-pc ... debconf-set-selections` pre-answers a debconf question so `apt-get upgrade` doesn't block.
- ⚠ `passwd -d` + `PermitEmptyPasswords yes` + `NOPASSWD:ALL` = a user with **no password**
  reachable by SSH. It's convenient but bad practice. Prefer key-only SSH.

---

## `srcs/docker-compose.yml`

- `name: inception`: the project name, which prefixes resources (`inception_...`).
- `image: mariadb:1.0`: image name = service name (☠ rule) with an explicit tag (not latest).
  ⚠ `mariadb`, `nginx`, `redis` are also official DockerHub names. Adding `pull_policy: build`
  avoids any accidental pull.
- **healthcheck** per service:
  - mariadb: `export MYSQL_PWD=...; mariadb -u"$$MARIADB_USER" -e "USE db;"`. `$$` means a literal
    `$` (evaluated inside the container, not by compose). `MYSQL_PWD` passes the password without
    it showing up in `ps`.
  - wordpress/adminer: `cgi-fcgi -bind -connect localhost:9000` makes a real FastCGI connection.
  - nginx: `wget --no-check-certificate https://127.0.0.1/healthz`, a dedicated `location = /healthz`.
  - redis: `redis-cli -a pw ping | grep -i pong`.
- `depends_on: condition: service_healthy` creates a startup DAG: mariadb+redis → wordpress →
  adminer → nginx → goaccess. That's why the WordPress script has no "wait for DB" loop.
- `secrets:` per service + top-level `secrets: file: ../secrets/x.txt` (the path is
  relative to the compose file). Inside the container: `/run/secrets/<name>`.
- `*_PASSWORD_FILE` env vars contain the **path** of the secret, not the value (a convention
  borrowed from official images).
- **Hardening**:
  - `cap_drop: [ALL]` removes every Linux capability, and `cap_add` gives back only what's needed
    (`NET_BIND_SERVICE` to bind 443/21 < 1024 as non-root; `SYS_CHROOT`, `SETUID`,
    `SETGID` for vsftpd's chroot and user switching).
  - `security_opt: no-new-privileges:true`: setuid binaries can't gain privileges.
  - `read_only: true` + `tmpfs:` makes the root filesystem read-only, with RAM-backed writable dirs.
  - `deploy.resources.limits/reservations` are cgroup CPU/RAM limits.
  - `init: true` (vsftpd) adds tini as PID 1, because vsftpd forks per connection.
- **Networks**: `inception-net-priv` is `internal: true` (no internet, no published ports
  possible), and `inception-net-pub` is a normal bridge. NGINX and vsftpd are on both. A fixed
  `ipam` subnet (`10.42.1.0/28` = 16 addresses) is used, which MariaDB's user host pattern relies on.
  - `aliases: [${DOMAIN_NAME}]` on NGINX lets other containers resolve `acaceres.42.fr` to
    NGINX (useful for WordPress loopback requests / cron).
- **Volumes**: `driver: local` + `driver_opts: {type: none, o: bind, device: ${DATA_DIR}/mariadb/}`,
  which is the named-volume-stored-in-/home/login/data technique (see doc 05).
- `restart: always` covers the crash requirement.

### `srcs/.example.env`
A committed template with **non-secret** variables. The real `.env` is git-ignored.

---

## `requirements/mariadb`

### `Dockerfile`
- `apk add mariadb mariadb-client`.
- Creates the user/group, `/run/mysqld` (socket + pid dir), and chowns `/var/lib/mysql`.
- `USER mariadb` runs as non-root. `ENTRYPOINT ["./init-db.sh"]` + `CMD ["mariadbd"]`.
### `conf/my.cnf`
- `[mariadbd]` group: `skip-networking=0` (Alpine's default disables TCP!),
  `bind-address=0.0.0.0` (listen on the container interface), `innodb-buffer-pool-size`
  (main InnoDB memory cache), `utf8mb4` (full Unicode, emojis).
### `tools/init-db.sh`
- `if [ "$1" != "mariadbd" ]; then exec "$@"; fi`: if you run another command
  (`docker run img sh`), skip the setup.
- `if [ ! -d /var/lib/mysql/mysql/ ]` → first run (the system DB doesn't exist yet).
- `mariadb-install-db --auth-root-authentication-method=normal`: ☠ this is what prevents
  root logging in through unix_socket **without a password**.
- `mariadbd &` + a **bounded** `while ! mariadb-admin ping` loop with a 30 s timeout, then
  the SQL heredoc, then `mariadb-admin shutdown` + `wait $PID`, then `exec`.
  The temporary background server is not the final process, and the loop has a timeout,
  so it respects the rules (but be ready to defend it, or use `--bootstrap` instead, see doc 08).
- SQL: removes anonymous users and the test DB, restricts root to localhost, sets the root
  password, and creates the DB + user for `10.42.1.%` and `localhost`.
- `--defaults-extra-file=./my.cnf` loads its config in addition to the defaults.

---

## `requirements/nginx`

### `Dockerfile`
- `apk add nginx openssl gettext` (gettext provides `envsubst`).
- Moves Alpine's `default.conf` away, copies its own configs, runs `set-nginx-environment.sh`
  **at build time** to create dirs and chown them to `www`, then `USER www`.
### `conf/nginx.conf`
- `daemon off;` keeps it in the foreground (PID 1). `worker_processes auto;` uses one worker per CPU.
- `include /etc/nginx/http.d/*.conf;` loads the virtual hosts (Alpine's convention is `http.d`).
- `access_log /var/www/access.log`: the log is written into the shared volume so the GoAccess container can read it.
- `server_tokens off;`, `gzip on;`, `client_max_body_size 64m;` (bigger uploads).
### `conf/nginx-server.conf.template`
- `listen ${NGINX_PORT} ssl;` with only 443 and no port 80 server.
- Security headers: `Strict-Transport-Security` (HSTS: the browser always uses HTTPS),
  `X-Frame-Options` (prevents clickjacking), `X-Content-Type-Options nosniff`, `Referrer-Policy`.
- `location = /healthz` returns 200 for the healthcheck.
- `location ^~ /wp-admin/adminer`: `^~` means "if this prefix matches, don't check regexes" →
  `fastcgi_pass adminer:9000` with `SCRIPT_FILENAME /var/www/adminer.php`.
- `location ~ \.php$` → `fastcgi_pass wordpress:9000`, `fastcgi_param HTTPS on` (WordPress knows it is behind HTTPS).
- `location ~ /\.` denies dotfiles (`.git`, `.env`, `.htaccess`).
### `conf/nginx-tls.conf`
- `ssl_protocols TLSv1.2 TLSv1.3;` ☠ is the key mandatory line.
- `ssl_ciphers` contains ECDHE (forward secrecy) + AEAD ciphers (GCM, ChaCha20) only.
- `ssl_session_cache` / `ssl_session_timeout` handle TLS session resumption (faster reconnects).
- `ssl_session_tickets off;` is recommended for forward secrecy.
### `tools/entrypoint.sh`
- Generates the certificate, then `envsubst '${NGINX_PORT} ${DOMAIN_NAME}' < template > conf`.
  The **restricted variable list** protects `$uri`, `$args`… Then `exec "$@"`.
### `tools/gen-cert.sh`
- Writes an OpenSSL config with `[req_distinguished_name]` (C, ST, L, O, OU, CN) and
  `subjectAltName` (DNS.1 / DNS.2), then `openssl genrsa 4096` + `openssl req -new -x509 -sha256 -days 365`.
- ⚠ It regenerates a 4096-bit key **at every container start**, which is slow, and the
  fingerprint changes every time. Better: generate only `if [ ! -f "$KEY" ]`.

---

## `requirements/wordpress`

### `Dockerfile`
- PHP 8.4 + the extensions WordPress needs (mysqli, curl, dom, mbstring, gd, intl, zip, opcache…).
- Downloads **wp-cli** and verifies its **sha512** (supply-chain integrity).
- `wp core download` happens **at build** into `/usr/src/wordpress`. At runtime it's copied into
  the volume, which makes first start faster and builds reproducible.
- Pre-downloads the redis-cache plugin zip and verifies its sha256.
- `sed ... cgi.fix_pathinfo=0`: a security setting so PHP doesn't execute "the closest
  matching file" for crafted URLs.
### `conf/www.conf` (PHP-FPM pool)
- `daemonize = no` keeps it in the foreground. `error_log = /proc/self/fd/2` sends errors to stderr, so they show in `docker logs`.
- `listen = 9000` listens on all interfaces, port 9000 (reachable from NGINX).
- `pm = dynamic` + `max_children`… sizes the worker pool.
- `clear_env = no` lets PHP read the container env (`getenv('MARIADB_USER')`).
- `security.limit_extensions = .php` means only `.php` files are executed.
### `tools/wp-setup.sh`
- Idempotency: `if [ -f wp-config.php ]; then exec "$@"`.
- `wp config create --skip-check` with placeholder values, then
  `wp config set DB_PASSWORD "trim(file_get_contents('/run/secrets/...'))" --raw`.
  `--raw` writes PHP code, not a string, so **wp-config.php contains no password**,
  only code that reads the secret at runtime. ✅ Nice design point.
- `wp core install` (admin) + `wp user create ... --role=author` (2nd user).
- `FORCE_SSL_ADMIN`, `DISALLOW_FILE_EDIT` (no theme/plugin editor in the dashboard, a security setting).
- `DISABLE_WP_CRON` / `ALTERNATE_WP_CRON`: WP-cron normally makes loopback HTTP requests.
- Redis: `WP_CACHE`, `WP_REDIS_*`, activates the plugin, `wp redis enable` (installs the drop-in).
- Deletes inactive plugins/themes, sets the timezone and permalinks (`/%postname%/`).

---

## Bonus services

### `adminer/`
PHP-FPM + `adminer.php` downloaded with its **sha256 checked**, `chmod 444` (read-only),
own pool config, `USER www`. NGINX sends `/wp-admin/adminer` to it.

### `redis/`
`redis.conf.template` + `envsubst` puts the password from the secret into the config at
start, then `unset` the variable. `maxmemory 400mb` + `allkeys-lru`, `requirepass`,
`protected-mode yes`, `daemonize no`. ⚠ It keeps RDB snapshots (`save ...`), which aren't
needed for a pure cache, and there is no volume, so the snapshot is lost anyway.

### `vsftpd/`
User `www` (uid 1000, same as PHP-FPM → same file ownership), `chpasswd` from the
secret, chroot to the WordPress dir, passive ports 21100-21105, `background=NO`,
`seccomp_sandbox=NO` (vsftpd's seccomp filter conflicts with Docker's).
⚠ No `pasv_address`: it works through Vagrant port-forwarding to localhost, but can break elsewhere.

### `website/`
lighttpd serving `index.html` + `index.css` on port 4000, published directly (not through NGINX).

### `goaccess/` (the reference's free choice)
lighttpd + a **CGI script** (`index.cgi`): each request runs `goaccess` on NGINX's
access log (read from the shared volume) and prints the HTML report. `index.html`
just redirects to `/index.cgi`. The entrypoint `touch`es the log so it exists.

---

## Docs files
`README.md`, `USER_DOC.md`, `DEV_DOC.md` follow the subject's required sections.
Read them to see the expected *level of detail*, then write yours in your own words.
