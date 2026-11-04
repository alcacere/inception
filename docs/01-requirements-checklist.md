# 01 — Requirements checklist (subject v5.3 + eval sheet)

Every line here is traceable to the subject (S, with page) or the eval sheet (E).
Tick them off before submitting. Anything marked ☠ ends the evaluation
immediately if wrong.

## General guidelines

- [ ] Everything is done inside a **Virtual Machine** (S p4).
- [ ] All configuration files live in **`srcs/`**, at the repo root (S p4, E).
- [ ] A **`Makefile`** at the repo root sets up the whole application, building
      the images through `docker-compose.yml` (S p4, E).

## Docker rules

- [ ] You use **`docker compose`** (S p7).
- [ ] ☠ **Each image has the same name as its service** (S p7, E "Docker Basics").
- [ ] Each service runs in **its own dedicated container** (S p7).
- [ ] ☠ Every image is built `FROM` the **penultimate stable Alpine or Debian** (S p7, E).
      → We use `alpine:3.23`.
- [ ] ☠ **One Dockerfile per service**, not empty, written by you (S p7, E).
- [ ] The Dockerfiles are called from `docker-compose.yml`, which is called by the Makefile (S p7).
- [ ] ☠ No ready-made images: **no pulling** `nginx`, `wordpress`, `mariadb`… from
      DockerHub. Only `alpine`/`debian` may be pulled (S p7, E).
- [ ] ☠ The **`latest` tag is forbidden** (S p8). Pin `alpine:3.23` and tag
      your own images explicitly.
- [ ] **No password in any Dockerfile** (S p8).
- [ ] **Environment variables** are used, and a **`.env` file** is mandatory (S p8).
- [ ] Docker **secrets** are strongly recommended for confidential data (S p8).
- [ ] ☠ **No credentials in Git** outside of properly configured secrets (S p8, p10).
      → `.env` and `secrets/*` are git-ignored.
- [ ] Containers **restart in case of a crash** (S p7).

## Forbidden things (E "General instructions" → evaluation ends)

- [ ] ☠ No `network: host` and no `links:` in `docker-compose.yml`.
- [ ] ☠ `docker-compose.yml` **does** contain `networks`.
- [ ] ☠ No `--link` in the Makefile or any script.
- [ ] ☠ No `tail -f`, no program started in background (`&`) in an ENTRYPOINT
      or in an entrypoint script. No `bash`/`sh` used except to run a script.
- [ ] ☠ No infinite loops in **any** script: `sleep infinity`, `tail -f /dev/null`,
      `tail -f /dev/random`, `while true`.
      → Careful with "wait until MariaDB is up" loops: they must be **bounded**
      (a timeout/retry counter), and you must be able to explain why they
      terminate. Better: use compose `healthcheck` + `depends_on: condition: service_healthy`.

## Mandatory services

- [ ] **NGINX** container, **TLSv1.2 or TLSv1.3 only** (S p7).
- [ ] ☠ NGINX is the **only entry point**, **port 443 only** (S p8, E).
      `http://alcacere.42.fr` (port 80) must **not** connect (E).
- [ ] **WordPress + php-fpm** container, installed and configured, **no nginx** in it (S p7, E).
- [ ] **MariaDB** container, **no nginx** in it (S p7, E).
- [ ] A **named volume** for the WordPress database (S p7).
- [ ] A **named volume** for the WordPress website files (S p7).
- [ ] ☠ **Bind mounts are not allowed** for those two volumes (S p7).
- [ ] Both volumes store their data in **`/home/alcacere/data`** on the host (S p7).
      E checks: `docker volume inspect <vol>` output contains `/home/alcacere/data/`.
- [ ] A **docker network** connects the containers (S p7).

## WordPress content

- [ ] **Two users** in the WordPress database, one is the **administrator** (S p8).
- [ ] ☠ The admin username does **not contain** `admin`/`Admin`/`administrator`/`Administrator`
      (e.g. `admin-123` is also forbidden) (S p8, E).
- [ ] The site is already installed: you **never** see the WordPress install page (E).
- [ ] The regular user can **post a comment** (E).
- [ ] The admin can **edit a page** and the change shows on the site (E).

## MariaDB

- [ ] ☠ Logging in as **root without password must fail** (E).
- [ ] You can log in with the regular DB user + password and the DB is **not empty** (E).
- [ ] You can explain how to log in to the database (E).

## Domain

- [ ] `alcacere.42.fr` points to the local IP (S p8) → `/etc/hosts` entry.

## Persistence (E)

- [ ] Reboot the VM → `make` / `docker compose up` again → everything works,
      WordPress and MariaDB are configured, **previous changes are still there**.

## Required documentation (S chapters VI and VII)

- [ ] `README.md` at the root, **in English**, with:
  - [ ] First line in italics, exactly:
        `*This project has been created as part of the 42 curriculum by alcacere.*`
  - [ ] **Description** section (goal + overview).
  - [ ] **Instructions** section (install / build / run).
  - [ ] **Resources** section (references + **how AI was used**, for which tasks and parts).
  - [ ] **Project description** section: use of Docker, sources included, main design
        choices, and the comparisons:
    - [ ] Virtual Machines vs Docker
    - [ ] Secrets vs Environment Variables
    - [ ] Docker Network vs Host Network
    - [ ] Docker Volumes vs Bind Mounts
- [ ] `USER_DOC.md`: services provided, start/stop, access website + admin panel,
      locate/manage credentials, check services are running.
- [ ] `DEV_DOC.md`: set up from scratch (prereqs, config files, secrets), build/launch
      with Makefile + Compose, commands to manage containers & volumes, where data
      is stored and how it persists.

## Oral part (E "Project overview") — you must explain simply

- [ ] How Docker and docker compose work.
- [ ] The difference between an image used with docker compose and without it.
- [ ] The benefit of Docker compared to VMs.
- [ ] The pertinence of the required directory structure.
- [ ] What a docker network is.
- [ ] How TLS is demonstrated (cert + protocol version).

## Bonus (S chapter VIII) — only graded if the mandatory part is PERFECT

- [ ] One Dockerfile per extra service, own container, own volume if needed.
- [ ] Redis cache for WordPress.
- [ ] FTP server container pointing to the WordPress volume.
- [ ] Static website in any language **except PHP**.
- [ ] Adminer.
- [ ] One service of your choice + justification → **Prometheus + Blackbox Exporter**.
- [ ] Extra ports may be opened for bonus services (S p15).

## Possible live modification (S chapter IX)

The evaluator may ask for a small change (e.g. change a port, add an env var,
change the WordPress title, add a user). Being able to do this in minutes is the
real proof you understand your files.
