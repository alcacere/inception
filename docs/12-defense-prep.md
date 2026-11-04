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
docker exec -it mariadb mariadb -u wp_user -p
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
Prometheus: show every target UP, then `probe_tls_version_info`, and the `nginx:80` probe at 0.

## Likely live modifications (practice these!)
- Change the WordPress site title / add a third user via env + WP-CLI.
- Change NGINX to TLS 1.3 only and prove 1.2 now fails.
- Change the Redis maxmemory, or a published port.
- Add an env var used by a container, then show it with `docker exec <c> env`.
- Rename a volume/network and rebuild.
