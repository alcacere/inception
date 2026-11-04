# 07 — WordPress, PHP-FPM, FastCGI, WP-CLI

## WordPress

**What is it?** The most used CMS (content management system), written in **PHP**,
storing content (posts, pages, users, comments, options) in a **MySQL/MariaDB**
database and files (core, themes, plugins, uploads) on disk.

**Why here?** It is the application the infrastructure serves. It needs the three
tiers: web server (NGINX), app runtime (PHP-FPM), database (MariaDB).

**Important files**
- `wp-config.php`: DB connection (`DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`),
  the security keys/salts, and constants (`WP_DEBUG`, `WP_REDIS_HOST`, `FORCE_SSL_ADMIN`…).
  Its existence is the usual "already installed?" test in your entrypoint.
- `wp-content/` holds themes, plugins and uploads, which is the data that must persist.
- `wp-admin/` is the administration dashboard.

**Roles**: Administrator, Editor, Author, Contributor, Subscriber. The second
user must be able to **comment**, so any role works (Author/Subscriber).

**Persisting "already installed"**: the files live in the `wordpress` volume and the
DB rows in the `mariadb` volume. On every start your script checks if WordPress is
installed (`wp core is-installed` or the presence of `wp-config.php`) and **skips
installation** if it is, which is what makes the "Persistence" test pass after a reboot.

**Docs**
- Advanced administration handbook: <https://developer.wordpress.org/advanced-administration/>
- `wp-config.php`: <https://developer.wordpress.org/advanced-administration/wordpress/wp-config/>
- Roles and capabilities: <https://wordpress.org/documentation/article/roles-and-capabilities/>
- Server requirements: <https://wordpress.org/about/requirements/>

---

## PHP-FPM

**What is it?** **FastCGI Process Manager**: a daemon that keeps a **pool** of PHP
worker processes ready to execute scripts, and speaks the **FastCGI** protocol on a TCP
port (9000) or a Unix socket.

**Why?** NGINX can't run PHP itself (unlike Apache's mod_php). The subject explicitly
wants "WordPress + php-fpm only, without nginx" in its container. Separating them
lets you scale and isolate them independently.

**Config files (Alpine, php84)**
- `/etc/php84/php-fpm.conf` is the global config (`daemonize`, `error_log`, includes the pool dir).
- `/etc/php84/php-fpm.d/www.conf` defines the **pool**:
  - `listen = 9000` (default is `127.0.0.1:9000`, which would only accept connections from
    inside the container. ☠ It must listen on all interfaces so NGINX can connect).
  - `user`/`group`: which user runs the workers.
  - `pm = dynamic|static|ondemand`, `pm.max_children`, `pm.start_servers`…: process management.
  - `clear_env = no`: lets workers see container env vars (`getenv()`).
  - `catch_workers_output = yes`: PHP errors go to `docker logs`.
- Run in foreground: `php-fpm84 -F` (or `daemonize = no`).

**Docs**
- Install/overview: <https://www.php.net/manual/en/install.fpm.php>
- Configuration: <https://www.php.net/manual/en/install.fpm.configuration.php>
- Alpine PHP packages: <https://pkgs.alpinelinux.org/packages?name=php84*&branch=v3.23>

---

## FastCGI

**What is it?** A binary protocol between a web server and an application server.
It's the successor of CGI. With CGI a new process was spawned for every request.
FastCGI keeps processes alive and multiplexes requests over a connection.

**Why it matters for the defense:** the arrow "9000" in the subject's diagram
between NGINX and WordPress is a FastCGI connection, not HTTP. NGINX sends
CGI variables (`SCRIPT_FILENAME`, `REQUEST_METHOD`, `QUERY_STRING`, headers) plus the
body, and PHP-FPM sends back headers + body.

Healthcheck trick: `cgi-fcgi -bind -connect 127.0.0.1:9000` (from the `fcgi` package)
checks that FPM answers.

**Docs**
- Specification: <https://fastcgi-archives.github.io/FastCGI_Specification.html>
- NGINX FastCGI module: <https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html>

---

## WP-CLI

**What is it?** The official command-line interface for WordPress (a `.phar`
PHP archive). It can download core, create `wp-config.php`, run the installer,
create users, install plugins, change options, all without a browser.

**Why?** ☠ The eval says you must **not** see the installation page. WP-CLI lets your
entrypoint install and configure WordPress automatically on first start.

**Commands for your setup script**
```
wp core download --path=/var/www/html     # run as the www user (as root WP-CLI requires --allow-root)
wp config create --dbname=... --dbuser=... --dbpass=... --dbhost=mariadb:3306
wp core install --url=https://alcacere.42.fr --title=Inception \
     --admin_user=<NOT admin> --admin_password=... --admin_email=... --skip-email
wp user create <user> <email> --role=author --user_pass=...
wp core is-installed           # exit 0 if installed → idempotency check
wp option update ...  /  wp plugin install redis-cache --activate  /  wp redis enable
```
Verify integrity when downloading wp-cli (`.sha512` file) and pin versions.

**Docs**
- Site: <https://wp-cli.org/>
- Commands: <https://developer.wordpress.org/cli/commands/>
- `core install`: <https://developer.wordpress.org/cli/commands/core/install/>
- `config create`: <https://developer.wordpress.org/cli/commands/config/create/>
- `user create`: <https://developer.wordpress.org/cli/commands/user/create/>

---

## Pitfalls
- ☠ Admin username containing `admin` (also `Admin`, `administrator`, `admin-123`).
  Validate it in your Makefile/check script!
- `wp core install` with the wrong `--url` (e.g. `http://` or a missing domain) causes
  redirect loops or wrong links. Use `https://alcacere.42.fr`.
- Starting PHP-FPM before the DB is ready: use `depends_on: service_healthy`.
- File ownership: NGINX (reads) and PHP-FPM (reads/writes uploads) share the volume,
  so align UIDs (e.g. both `www` uid 1000 or `nobody`) or uploads fail.
- Don't put the DB password in `wp-config.php` in clear text if you can avoid it: the
  reference reads it at runtime with `file_get_contents('/run/secrets/...')`. It's a nice design point.
