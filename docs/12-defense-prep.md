# 12 — Defense preparation (eval sheet, step by step)

Rehearse this whole script in the VM at least twice, from a **fresh clone**.

## 0. Preliminaries
- The evaluator clones your repo into an **empty folder on your station** (the VM).
  → `make` must work from a fresh clone: `.env` and secrets are missing!
  Your Makefile must explain how to create them (e.g. `make secrets` + copying
  `.env.example`) or generate them.
- They run the cleanup command (it deletes **all** images, including `alpine:3.23`,
  so the VM needs internet to pull Alpine again):
  ```
  docker stop $(docker ps -qa); docker rm $(docker ps -qa);
  docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q);
  docker network rm $(docker network ls -q) 2>/dev/null
  ```
- They grep for: `network: host`, `links:`, `--link`, `tail -f`, `sleep infinity`,
  `while true`, background `&`, `bash`/`sh` misuse. Run the same greps yourself:
  ```
  grep -rnE "network(_mode)?: *host|links:|--link|tail -f|sleep infinity|while true" .
  grep -rn "&\s*$" srcs/requirements --include=*.sh
  grep -rn "latest" srcs/
  ```

## 1. Project overview (oral): prepare 1–2 sentences each
- **How Docker works**: images (layers), containers (isolated processes via
  namespaces/cgroups sharing the kernel), daemon + CLI. See doc 03.
- **How compose works**: one YAML describing services/networks/volumes/secrets, and
  `up` builds and starts everything in dependency order. See doc 04.
- **Image with vs without compose**: same image. Compose declares its run
  configuration and orchestration. See doc 04.
- **Docker vs VM**: see doc 05 §1.
- **Directory structure pertinence**: `Makefile` is the entry point. `srcs/` holds all the config
  (the compose file + `.env`). `requirements/<service>/` gives one build context per service
  (Dockerfile, `conf/`, `tools/`, `.dockerignore`), so each image only sees its own files.
  `secrets/` stays outside `srcs` and out of Git, and `bonus/` separates the optional services.

## 2. Simple setup
```
curl -vk https://alcacere.42.fr          # WordPress page, TLS info in the output
curl -v  http://alcacere.42.fr           # must FAIL (connection refused)
docker ps --format '{{.Names}}\t{{.Ports}}'   # only nginx publishes 443 (+ bonus ports)
```
Browser: `https://alcacere.42.fr`. There's a self-signed warning, then the site (not the installer).

## 3. Docker basics
```
ls srcs/requirements/*/Dockerfile srcs/requirements/bonus/*/Dockerfile
head -1 srcs/requirements/*/Dockerfile srcs/requirements/bonus/*/Dockerfile   # FROM alpine:3.23
docker images            # REPOSITORY == service name, TAG != latest
```

## 4. Docker network
```
docker network ls
docker network inspect inception_<net>    # shows the containers attached
docker exec wordpress ping -c1 mariadb   # or: getent hosts mariadb (DNS by name)
```

## 5. NGINX with SSL/TLS
```
docker compose -f srcs/docker-compose.yml ps
openssl s_client -connect alcacere.42.fr:443 -tls1_2 </dev/null | grep -E "Protocol|Cipher"
openssl s_client -connect alcacere.42.fr:443 -tls1_3 </dev/null | grep -E "Protocol|Cipher"
openssl s_client -connect alcacere.42.fr:443 -tls1_1 </dev/null        # handshake failure
```

## 6. WordPress + php-fpm + volume
```
grep -i nginx srcs/requirements/wordpress/Dockerfile      # nothing
docker volume ls
docker volume inspect inception_wordpress | grep device    # /home/alcacere/data/wordpress
```
Browser: log in as the regular user → comment on a post. Log in as admin
(`/wp-admin`) → edit a page → the change is visible on the site.

## 7. MariaDB + volume
```
docker volume inspect inception_mariadb | grep device      # /home/alcacere/data/mariadb
docker exec -it mariadb mariadb -u root                     # Access denied ✔
docker exec -it mariadb mariadb -u wp_dbuser -p
  > SHOW DATABASES; USE wordpress; SHOW TABLES; SELECT user_login FROM wp_users;
```

## 8. Persistence
```
sudo reboot
# after reboot:
cd ~/inception && make
```
Site works, no installer, and your comment and page edit are still there.

## 9. Crash/restart demo (not in the sheet, but it's a subject rule)
```
sudo kill -9 "$(docker inspect -f '{{.State.Pid}}' nginx)"; sleep 3; docker ps   # restarted
# Not `docker kill`: that counts as a manual stop, and the container stays down.
```

## 10. Bonus
For each one: show the container, its Dockerfile, a working demo, and explain *why*.
The live demo for every service is in §11 below.

## 11. Service-by-service demo walkthrough
One story that touches every container. Do it in this order: each step builds on the
previous one, and the comment/upload created here are what you show again after the
reboot in §8.

Before you start:
```
make ps                                   # all 9 containers Up (healthy)
cat secrets/wp_user_password.txt          # have the passwords at hand
cat secrets/wp_admin_password.txt
```

### 11.1 NGINX: the only entry point
```
curl -sk -o /dev/null -w '%{http_code}\n' https://alcacere.42.fr/          # 200
curl -sk -o /dev/null -w '%{http_code}\n' https://alcacere.42.fr/adminer   # 200
curl -sk -o /dev/null -w '%{http_code}\n' https://alcacere.42.fr/portfolio/ # 200
curl -sk -o /dev/null -w '%{http_code}\n' https://alcacere.42.fr/prometheus/-/healthy # 200
docker ps --format '{{.Names}}\t{{.Ports}}'   # only nginx (443) and ftp (21, 21000-21010) publish
```
Say: every web UI (WordPress, Adminer, portfolio, Prometheus) goes through the same
TLS server block. The backends have no published ports.

### 11.2 WordPress: blog, login, comment moderation
Requires `comment_moderation 1` (+ `comment_registration 1`) in the WordPress entrypoint.
1. Private window → `https://alcacere.42.fr` → the demo post is there, and the comment
   form asks you to log in (anonymous visitors can't comment).
2. Log in as **`wp_author`** (`/wp-login.php`) → comment on the post
   → "Your comment is awaiting moderation". Log out.
3. Log in as admin **`alcacere`** → `/wp-admin` → **Comments** → the comment is under
   **Pending** → **Approve** (or **Spam/Trash** to show rejection).
4. Reload the post as a visitor → the approved comment is public.
5. Show the regular user can't moderate: logged in as `wp_author`, `/wp-admin` has no
   Comments → Approve action (role *author* lacks `moderate_comments`).

Say: the admin username has no "admin" in it (subject rule), and php-fpm runs alone in
its container. NGINX forwards `.php` to `wordpress:9000` over FastCGI.

### 11.3 MariaDB: the comment is really in the database
```
docker exec -it mariadb mariadb -u wp_dbuser -p wordpress
  > SELECT comment_ID, comment_author, comment_approved FROM wp_comments;
  #   approved = 0 before approval, 1 after, 'spam' / 'trash' if rejected
  > SELECT user_login, user_email FROM wp_users;    # alcacere + wp_author
docker exec -it mariadb mariadb -u root          # Access denied (root needs the password)
```
Optional live proof: run the SELECT, approve/unapprove in wp-admin, and run it again.

### 11.4 Adminer: same data in a browser
`https://alcacere.42.fr/adminer` → System **MySQL**, Server **mariadb**, User
**wp_dbuser**, password from `secrets/db_password.txt`, Database **wordpress**
→ open `wp_comments` → the same row as in 11.3.
Say: Adminer has no published port, it's PHP-FPM behind the same NGINX, and it reaches
MariaDB by container name on the `inception` network.

### 11.5 FTP: files land in the WordPress volume
```
echo "uploaded via ftp" > ftp-test.txt
curl -u ftp_user:"$(cat secrets/ftp_password.txt)" \
     -T ftp-test.txt ftp://alcacere.42.fr/wp-content/uploads/
curl -u ftp_user:"$(cat secrets/ftp_password.txt)" ftp://alcacere.42.fr/   # lists WordPress root
curl -k https://alcacere.42.fr/wp-content/uploads/ftp-test.txt              # served by nginx
ls -l /home/alcacere/data/wordpress/wp-content/uploads/ftp-test.txt         # on the host volume
curl ftp://alcacere.42.fr/   # anonymous → 530 Login incorrect
```
Say: the ftp container mounts the same `wordpress` volume as wordpress and nginx.
Passive ports 21000-21010 are published, with `pasv_address` = VM IP. Users are
chrooted to `/var/www/html`.

### 11.6 Redis: WordPress object cache
```
docker exec wordpress wp redis status --allow-root --path=/var/www/html   # Status: Connected
docker exec redis sh -c 'redis-cli -a "$(cat /run/secrets/redis_password)" --no-auth-warning DBSIZE'
docker exec redis sh -c 'redis-cli -a "$(cat /run/secrets/redis_password)" --no-auth-warning MONITOR'
#   → reload the site in the browser: GET/SET lines scroll by. Ctrl-C to stop.
docker exec redis redis-cli PING        # NOAUTH error: password required
```
Also visible in wp-admin → **Settings → Redis**.
Say: Redis caches the results of MariaDB queries in memory (128 MB, LRU). It's a cache
only (no persistence), so deleting it loses nothing.

### 11.7 Static website (portfolio)
`https://alcacere.42.fr/portfolio/` → page + Snake game.
```
docker exec website ps        # darkhttpd, no PHP anywhere
```
Say: the subject requires a static site in any language except PHP. It's served by
darkhttpd on 8080 and reverse-proxied by NGINX.

### 11.8 Prometheus + Blackbox: monitoring all of the above
`https://alcacere.42.fr/prometheus/` →
- **Status → Targets**: `prometheus`, `blackbox-https` (`https://nginx:443`) and
  `blackbox-tcp` (`nginx:443`, `mariadb:3306`, `redis:6379`, `ftp:21`) are all **UP**.
- **Graph**: `probe_success` (all 1), `probe_tls_version_info` (TLS 1.2/1.3),
  `(probe_ssl_earliest_cert_expiry - time()) / 86400` (certificate days left).

Live failure demo:
```
docker stop redis
# ~15 s later: probe_success{instance="redis:6379"} = 0
# Alerts tab: ServiceDown → pending, then firing after 1 min
docker start redis    # back to 1, alert resolves
```
Say: Blackbox probes from outside each service (like a user would), and Prometheus
scrapes it and evaluates the alert rules.

### 11.9 Close the loop: persistence
Do §8 (reboot → `make`). Then show the approved comment, `ftp-test.txt` and the
Prometheus history are all still there, because they live in `/home/alcacere/data/*`.

## Likely live modifications (practice these!)
- Change the WordPress site title / add a third user via env + WP-CLI.
- Change NGINX to TLS 1.3 only and prove 1.2 now fails.
- Change the Redis maxmemory, or a published port.
- Add an env var used by a container, then show it with `docker exec <c> env`.
- Rename a volume/network and rebuild.
