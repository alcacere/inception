# 03 — Docker fundamentals

## What is Docker?

A platform to **build, ship and run applications in containers**. A container
is a normal Linux process (or group of processes) that the kernel **isolates**:
- **Namespaces** decide what the process can *see*: its own PID tree (`pid`),
  network stack (`net`), mount table (`mnt`), hostname (`uts`), IPC, users.
- **cgroups** decide how much it can *use*: CPU, memory, I/O, number of PIDs
  (this is what `deploy.resources.limits` configures).
- **Capabilities + seccomp + no-new-privileges** decide what it is *allowed to do*,
  even as "root" inside the container.
- **Union filesystem (overlayfs)** gives it its own root filesystem built from
  image layers + one writable layer.

There is **no guest kernel**: every container shares the VM's kernel.

### Architecture (what happens on `docker run`)
```
docker CLI ──REST API (/var/run/docker.sock)──► dockerd ──► containerd ──► runc ──► your process
```
- `dockerd`: the daemon. It builds images and manages networks and volumes.
- `containerd`: manages the container lifecycle.
- `runc`: the low-level OCI runtime. It creates the namespaces and cgroups and then execs your process.

**Docs**
- Overview: <https://docs.docker.com/get-started/docker-overview/>
- Namespaces: <https://man7.org/linux/man-pages/man7/namespaces.7.html>
- cgroups: <https://man7.org/linux/man-pages/man7/cgroups.7.html>
- Capabilities: <https://man7.org/linux/man-pages/man7/capabilities.7.html>
- OCI specs: <https://opencontainers.org/>

---

## Image vs container

| Image | Container |
|-------|-----------|
| Read-only template: stacked **layers** + metadata (CMD, ENV, EXPOSE, USER…) | A running (or stopped) **instance** of an image plus a thin writable layer |
| Built with `docker build` from a Dockerfile | Created with `docker run` / `docker compose up` |
| Identified by `name:tag` and a digest | Identified by name/ID, has state (running, exited, restarting) |

Each Dockerfile instruction that changes the filesystem (`RUN`, `COPY`, `ADD`)
creates a **layer**. Layers are cached: if an instruction and its inputs haven't
changed, Docker reuses the cached layer. **Order matters**: put the things that
rarely change (package installs) before the things that change often (your config files).

Anything written inside the container's writable layer **is lost** when the
container is removed. This is why the database and WordPress files go in **volumes**.

---

## Dockerfile instructions you will use

| Instruction | What it does | Notes for Inception |
|-------------|--------------|---------------------|
| `FROM alpine:3.23` | Base image | ☠ Must be penultimate Alpine/Debian, **never `latest`** |
| `RUN apk add --no-cache pkg` | Run a command at **build** time, new layer | `--no-cache` avoids storing the apk index → smaller image |
| `COPY src dst` | Copy files from the **build context** | Prefer `COPY` to `ADD` (ADD also extracts tarballs and fetches URLs) |
| `WORKDIR /path` | Set cwd for following instructions and for the container | |
| `ENV KEY=value` | Env var baked into the image | ☠ **Never secrets** (visible in `docker history`/`inspect`) |
| `ARG KEY` | Build-time variable | Also visible in history: no secrets either |
| `EXPOSE 9000` | **Documentation** of the listening port | It does **not** publish anything. `ports:` in compose publishes |
| `USER www` | Run as a non-root user from here on | Good practice. Needs dirs owned by that user |
| `ENTRYPOINT ["/entrypoint.sh"]` | The executable that always runs | Use **exec form** (JSON array) |
| `CMD ["php-fpm84", "-F"]` | Default arguments (passed to ENTRYPOINT) | Overridable at `docker run img <cmd>` |
| `HEALTHCHECK` | How to test the service is healthy | We define it in compose instead (either is fine) |
| `STOPSIGNAL` | Signal sent by `docker stop` | Default SIGTERM |

### `.dockerignore`
Lists files excluded from the **build context** (what is sent to the daemon).
It keeps builds fast and prevents leaking files (e.g. `.env`, `.git`) into
images. The subject's example tree shows one per service.

### Exec form vs shell form
- `CMD ["nginx", "-g", "daemon off;"]` (**exec form**): the process is executed
  directly, and it **is PID 1**, so it receives signals.
- `CMD nginx -g "daemon off;"` (**shell form**): runs `/bin/sh -c "..."`. Then `sh` is
  PID 1 and may not forward SIGTERM, so `docker stop` waits 10 s and SIGKILLs.

**Docs**
- Dockerfile reference: <https://docs.docker.com/reference/dockerfile/>
- Best practices: <https://docs.docker.com/build/building/best-practices/>
- Build context & .dockerignore: <https://docs.docker.com/build/concepts/context/>
- Build cache: <https://docs.docker.com/build/cache/>

---

## PID 1, daemons and why `tail -f` is forbidden

The subject says: *"Read about PID 1 and the best practices for writing Dockerfiles"*
and *"A Docker container is not a virtual machine"*.

**A container lives exactly as long as its PID 1 lives.** When PID 1 exits, the
container stops.

**Daemon** = a program that *forks into the background* and detaches (classic
`nginx`, `mysqld_safe`, `php-fpm` default behaviour, `vsftpd` with
`background=YES`). If your PID 1 daemonizes, the parent exits, the container
stops, and `restart: always` restarts it forever (a crash loop).

**Hacky "fix" (forbidden):** start the daemon in the background and keep the container
alive with `tail -f /dev/null`, `sleep infinity` or `while true`. Then PID 1 is `tail`:
- your real service can crash and the container still says "Up", so `restart` never triggers;
- `docker stop` signals `tail`, not your service, so there is no graceful shutdown;
- logs don't go to `docker logs`.

**Correct way:** run the service **in the foreground** as PID 1:
| Service | Foreground switch |
|---------|-------------------|
| NGINX | `daemon off;` in nginx.conf or `-g 'daemon off;'` |
| PHP-FPM | `php-fpm84 -F` or `daemonize = no` in config |
| MariaDB | `mariadbd` runs in foreground by default (don't use `mysqld_safe`) |
| Redis | `daemonize no` (default) |
| vsftpd | `background=NO` in vsftpd.conf |
| Prometheus / Blackbox Exporter | foreground by default |

### Responsibilities of PID 1
1. **Signals**: the kernel doesn't apply default signal actions to PID 1, so it
   must handle SIGTERM itself. Real servers do. `sh` scripts usually don't.
2. **Reaping zombies**: orphaned child processes are re-parented to PID 1. If
   it never calls `wait()`, they stay as zombies.
   → `init: true` in compose injects **tini** as PID 1 to forward signals and reap zombies.

### The entrypoint-script pattern (`exec "$@"`)
```
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mariadbd"]
```
The script does one-time setup (read secrets, init DB, render config) and ends
with `exec "$@"`. `exec` **replaces** the shell process by the CMD, so the
service **becomes PID 1**. Without `exec` the shell stays PID 1 and the service
is its child.

**Docs**
- Run multiple processes / init: <https://docs.docker.com/engine/containers/multi-service_container/>
- `docker run --init`: <https://docs.docker.com/reference/cli/docker/container/run/#init>
- tini: <https://github.com/krallin/tini>
- Signals: <https://man7.org/linux/man-pages/man7/signal.7.html>
- Article: "Containers and signal handling: why you need to care about PID 1":
  <https://denibertovic.com/posts/containers-and-signal-handling-why-you-need-to-care-about-pid-1/>

---

## Alpine Linux (our container base)

**What?** A tiny distribution (~8 MB image) built on **musl libc** and **BusyBox**,
with the **apk** package manager and OpenRC (which we don't use: containers have no init system).

**Why?** The subject requires penultimate Alpine or Debian "for performance
reasons". Alpine images are small, fast to build and have a reduced attack surface.

**Things that differ from Debian**
- `apk add --no-cache pkg` instead of `apt-get install`.
- `/bin/sh` is BusyBox ash, **not bash** → write POSIX sh scripts.
- `adduser -D -H -u 1000 -G www www` (BusyBox flags) instead of Debian's `useradd`.
- Package names are versioned for PHP: `php84`, `php84-fpm`, `php84-mysqli`…
- Search packages: <https://pkgs.alpinelinux.org/packages?branch=v3.23>
- Many packages are in the **community** repo (enabled by default in the image).

**Penultimate-version trap:** as of 2026-10-28 → latest **3.24**, penultimate **3.23**.
Alpine releases around May/June and Nov/Dec. If 3.25 is released before your
defense, the penultimate becomes 3.24. Re-check and bump `FROM` everywhere (one grep).

**Docs**
- Releases: <https://alpinelinux.org/releases/>
- apk: <https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper>
- Users/groups: <https://wiki.alpinelinux.org/wiki/Setting_up_a_new_user>

---

## Essential Docker CLI commands

```
docker build -t name:tag path        docker images / docker image ls
docker run --rm -it img sh           docker ps -a
docker logs -f <c>                   docker exec -it <c> sh
docker inspect <c|img|vol|net>       docker history <img>      # layers
docker stop / start / restart <c>    docker rm <c> / docker rmi <img>
docker volume ls / inspect / rm      docker network ls / inspect / rm
docker system df / docker system prune -a
docker stats                          docker top <c>             # processes, check PID 1
```

**Docs:** CLI reference: <https://docs.docker.com/reference/cli/docker/>
