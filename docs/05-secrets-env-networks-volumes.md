# 05 — The four comparisons (README "Project description")

The README must compare: **VM vs Docker**, **Secrets vs Env vars**,
**Docker network vs Host network**, **Docker volumes vs Bind mounts**.
Write them in your own words. This page gives you the material.

---

## 1. Virtual Machines vs Docker

| | Virtual machine | Docker container |
|-|-----------------|------------------|
| Virtualizes | Hardware (CPU, RAM, disk, NIC) | The OS (process isolation in the host kernel) |
| Kernel | Own guest kernel | Shares the host kernel |
| Boot | Seconds to minutes (full OS boot) | Milliseconds (just start a process) |
| Size | GBs (full OS) | MBs (only userland + app) |
| Isolation | Strong (hypervisor boundary) | Weaker (kernel shared: kernel bug = escape risk) |
| Density | A few per host | Dozens/hundreds |
| Portability | Image tied to hypervisor format | Same image runs on any Linux Docker host |
| Can run other OS kernels | Yes (Windows VM on Linux) | No (Linux containers need a Linux kernel) |

**Benefit of Docker vs VM (eval question):** lighter, faster, reproducible
("works on my machine" solved by shipping the environment), one process per
container, easy to rebuild/destroy, declarative infra (Compose).

**Why we use both:** the VM gives an isolated, disposable *host* where we are root;
Docker gives per-service isolation *inside* it. "One container is not enough, we
need to go deeper": that's where the name Inception comes from.

---

## 2. Secrets vs Environment variables

**Environment variables**
- Key/value pairs in the process environment.
- Visible with `docker inspect <c>` (Config.Env), `docker exec <c> env`,
  `/proc/<pid>/environ`, inherited by **every child process**, often dumped in
  logs/crash reports, and baked into image history if set with `ENV`.
- Good for **non-sensitive configuration**: domain name, DB name, usernames, ports.

**Docker (Compose) secrets**
- Declared at top level (`secrets: db_password: file: ../secrets/db_password.txt`)
  and granted per service.
- Mounted as a **file** at `/run/secrets/<name>` (read-only) only in the services
  that list them, and they do **not** appear in `docker inspect` env.
- With Compose (non-Swarm), secrets are implemented as read-only bind mounts of
  the file. In Swarm they are encrypted at rest and stored in tmpfs. Know this nuance.
- The application reads the file (`$(cat /run/secrets/db_password)`), or uses the
  `*_FILE` convention (env var holds the *path*, not the value).

**Rule for this project:** passwords → `secrets/*.txt` (git-ignored); everything
else → `srcs/.env` (git-ignored, with a committed `.env.example` template).

**Docs**
- Compose secrets: <https://docs.docker.com/compose/how-tos/use-secrets/>
- `secrets` top-level: <https://docs.docker.com/reference/compose-file/secrets/>
- Swarm secrets (how they work internally): <https://docs.docker.com/engine/swarm/secrets/>

---

## 3. Docker network vs Host network

**Bridge (user-defined) network**: what we use
- Docker creates a virtual switch (Linux bridge `br-xxxx`) and gives each container a
  virtual interface (veth pair) with a private IP in a subnet.
- **Embedded DNS** (127.0.0.11): containers resolve each other **by service name**
  (`mariadb:3306`, `wordpress:9000`). The default `bridge` network has no DNS,
  which is one reason `--link` existed. It is now legacy and ☠ forbidden here.
- Isolation: only ports listed in `ports:` are reachable from outside (NAT via iptables/nftables).
- `internal: true` creates a network with **no outbound internet**: useful for the DB.

**Host network** (`network_mode: host`): ☠ forbidden
- The container uses the host's network stack directly: no isolation, no port
  mapping, port conflicts, and every listening port is exposed. You also lose service-name DNS.

**Eval question "explain docker-network simply":** *"a private virtual LAN that
Docker creates for my containers. They talk to each other by name, and only NGINX
has a door (port 443) open to the outside."*

**Docs**
- Networking overview: <https://docs.docker.com/engine/network/>
- Bridge driver: <https://docs.docker.com/engine/network/drivers/bridge/>
- Host driver: <https://docs.docker.com/engine/network/drivers/host/>
- Compose networking: <https://docs.docker.com/compose/how-tos/networking/>
- Legacy links: <https://docs.docker.com/engine/network/links/>

---

## 4. Docker volumes vs Bind mounts

**Bind mount** (`./data:/var/lib/mysql` or `/home/x:/y`)
- Mounts an arbitrary **host path** into the container. It's managed by you, not Docker.
- Depends on the host directory layout, permissions/UIDs clash, invisible to `docker volume ls`.

**Named volume** (`db:/var/lib/mysql` + top-level `volumes: db:`)
- Storage **managed by Docker** (default: `/var/lib/docker/volumes/<name>/_data`).
- Listed and inspected with `docker volume ls/inspect`. The lifecycle is independent of
  containers. Easy to back up, share between services, use with drivers.
- When the volume is empty and mounted on an image path that has content, Docker
  **copies the image content into it** on first use (bind mounts don't).

**The subject's apparent contradiction:** "named volumes, bind mounts not allowed"
but "data must be in `/home/alcacere/data`". Solution: a **named volume using the
`local` driver with bind options**:

```yaml
volumes:
  mariadb:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/alcacere/data/mariadb
```

It *is* a named volume (shown in `docker volume ls`, managed via the volume API),
and `docker volume inspect` shows `"device": "/home/alcacere/data/mariadb"` in
Options, which is exactly what the eval checks. The directory must **exist
before** `up` (the Makefile creates it). Be ready to explain that under the hood
the local driver performs a `mount --bind`. What the subject forbids is the
*service-level bind mount syntax* (`- /home/...:/var/lib/mysql`).

⚠ **Side effect: ownership.** Because the data really lives in a host directory,
the container sees the **host's** owner/permissions. A `chown` in the Dockerfile
does not apply to it, and the "copy image content into an empty volume" behaviour
may not happen either. Plan the UIDs (e.g. chown in the entrypoint as root and then drop to
the service user, or align UIDs) for MariaDB, WordPress/FTP and Prometheus.

**Docs**
- Volumes: <https://docs.docker.com/engine/storage/volumes/>
- Bind mounts: <https://docs.docker.com/engine/storage/bind-mounts/>
- Compose `volumes` top-level: <https://docs.docker.com/reference/compose-file/volumes/>
- `docker volume create` (driver opts): <https://docs.docker.com/reference/cli/docker/volume/create/>
- tmpfs: <https://docs.docker.com/engine/storage/tmpfs/>
