# 04 — Docker Compose

## What is it?

A tool to define and run **multi-container applications** from one declarative
YAML file (`docker-compose.yml` / `compose.yaml`). Since Compose v2 it is a
Docker CLI plugin: `docker compose ...` (with a space).

## Why do we use it?

The subject requires it. Without Compose you would type, for each container,
`docker network create`, `docker volume create`, `docker build`, `docker run`
with a dozen flags, all in the right order. Compose turns all that into **one
file describing the desired state** + `docker compose up`.

### "Image used with docker compose vs without" (eval question)
- **Without compose:** you `docker build -t nginx:inception .` then `docker run`
  with every option (`-p`, `-v`, `--network`, `-e`, `--restart`…) by hand, one
  container at a time, and you handle the ordering yourself.
- **With compose:** the same image, but its build context, name/tag, ports,
  volumes, networks, env, secrets, restart policy, health and dependencies are
  declared in YAML. Compose creates a project-scoped network and volumes, builds
  the images, names the resources `<project>_<name>`, starts things in dependency
  order and can tear everything down with `down`.
- The image itself is identical. What changes is **how it is configured and orchestrated**.

**Docs**
- Overview: <https://docs.docker.com/compose/>
- How Compose works: <https://docs.docker.com/compose/intro/compose-application-model/>
- Compose file reference: <https://docs.docker.com/reference/compose-file/>
- CLI: <https://docs.docker.com/reference/cli/docker/compose/>

---

## Top-level elements of our file

```yaml
name: inception        # project name (prefix of networks/volumes/containers)
services:   {...}      # one entry per container
networks:   {...}      # user-defined networks
volumes:    {...}      # named volumes
secrets:    {...}      # files mounted at /run/secrets/<name>
```

## Service keys you will use (and why)

| Key | Purpose | Inception note |
|-----|---------|----------------|
| `build: ./requirements/nginx` | Build from your Dockerfile | ☠ Required: no `image:` pulled from DockerHub |
| `image: nginx:inception` | Name+tag given to the **built** image | ☠ Name must equal the service name. ☠ Tag ≠ `latest` |
| `pull_policy: build` | Always build, never try to pull | Prevents compose from pulling the real `nginx` from DockerHub if the image is missing |
| `container_name: nginx` | Fixed container name | Optional, but `docker ps` reads better |
| `restart: unless-stopped` / `always` / `on-failure` | Restart policy | ☠ "restart in case of a crash". `unless-stopped` also survives VM reboot (if dockerd is enabled) except when you stopped it by hand |
| `ports: ["443:443"]` | Publish host:container port | ☠ Only NGINX on 443 for mandatory. Never publish 3306/9000 |
| `expose: ["9000"]` | Document internal port | Not published to the host |
| `networks: [inception]` | Attach to a network | ☠ The `networks` key must exist |
| `volumes: ["wordpress:/var/www/html"]` | Mount a named volume | Use the **named** volume, not `./path:/path` |
| `env_file: .env` / `environment:` | Inject env vars | Non-secret config only |
| `secrets: [db_password]` | Mount `/run/secrets/db_password` | Passwords |
| `depends_on: {mariadb: {condition: service_healthy}}` | Start order + wait for health | Avoids "wait until DB is up" loops |
| `healthcheck:` | Command telling if the service works | Shown as `(healthy)` in `docker ps` |
| `init: true` | tini as PID 1 | Signal forwarding + zombie reaping |
| `read_only`, `tmpfs`, `cap_drop`, `cap_add`, `security_opt: [no-new-privileges:true]` | Hardening | Optional, good to explain in the defense |
| `deploy.resources.limits` | cgroup limits | Optional |

☠ **Forbidden:** `network_mode: host`, `links:`, `--link`.

---

## Variable interpolation and `.env`

Compose reads `srcs/.env` (the file next to the compose file, or the one given with
`--env-file`) and replaces `${VAR}` **inside the YAML** (interpolation). That is
different from `env_file:`, which injects variables **into the container**.

```
${VAR}            value or empty
${VAR:-default}   default if unset/empty
${VAR:?error}     fail with message if unset/empty   ← good for required vars
```

Precedence (simplified): shell environment > `--env-file`/`.env` for interpolation.

**Docs**
- Interpolation: <https://docs.docker.com/reference/compose-file/interpolation/>
- Env vars how-to: <https://docs.docker.com/compose/how-tos/environment-variables/>
- Precedence: <https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/>

---

## Healthchecks and `depends_on`

`depends_on` alone only orders **container start**, not "service ready".
MariaDB may need several seconds to initialize. With:

```yaml
depends_on:
  mariadb:
    condition: service_healthy
```

Compose waits until MariaDB's `healthcheck` passes before starting WordPress.
This replaces the classic (and risky) `while ! mysqladmin ping; do sleep 1; done`
in the WordPress script.

`healthcheck` fields: `test`, `interval`, `timeout`, `retries`, `start_period`.
Remember `$$` in compose to write a literal `$` (a single `$` is interpolated by compose).

**Docs**
- `depends_on`: <https://docs.docker.com/reference/compose-file/services/#depends_on>
- `healthcheck`: <https://docs.docker.com/reference/compose-file/services/#healthcheck>
- Startup order: <https://docs.docker.com/compose/how-tos/startup-order/>

---

## Restart policies

| Policy | Restarts when… |
|--------|----------------|
| `no` | never |
| `on-failure[:N]` | exit code ≠ 0 |
| `always` | always, also at daemon start, even after a manual stop (once dockerd restarts) |
| `unless-stopped` | like `always` but not if you stopped it manually |

Demo for the evaluator: kill the process from outside Docker, then watch it come back:
`sudo kill -9 "$(docker inspect -f '{{.State.Pid}}' nginx)"`.

⚠ **Don't use `docker kill` for this.** Docker counts it as a manual stop, so the restart policy
doesn't fire and the container stays `exited` (tested with `restart: always`). An evaluator could
read that as a failure.

**Docs:** <https://docs.docker.com/engine/containers/start-containers-automatically/>

---

## Commands you'll use (via the Makefile)

```
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d --build
docker compose -f srcs/docker-compose.yml ps        # ← eval uses this (-p allowed)
docker compose -f srcs/docker-compose.yml logs -f wordpress
docker compose -f srcs/docker-compose.yml down       # stop + remove containers & networks
docker compose -f srcs/docker-compose.yml down -v --rmi all   # + volumes + images
docker compose -f srcs/docker-compose.yml config     # print the resolved file (debug!)
docker compose -f srcs/docker-compose.yml exec mariadb sh
```

`docker compose config` is your best debugging tool: it shows the YAML after
interpolation, so you see exactly what Compose understood.
