# Inception — Study Guide (index)

This folder is **your learning material**, not part of what the subject requires.
The only sources of truth are `inception_en_subject.pdf` (v5.3) and the evaluation
sheet (`inception.pdf`). Everything here is derived from them, using
`acaceres_inception/` only as inspiration.

> Decisions taken for this project
> - Login: **alcacere** → domain `alcacere.42.fr`, data in `/home/alcacere/data`
> - VM: **Packer** builds a Debian box from the official ISO (unattended via
>   **preseed**), **Vagrant** runs it on **VirtualBox**.
> - Container base image: **Alpine 3.23** (penultimate stable on 2026-10-28;
>   latest is 3.24). Re-check <https://alpinelinux.org/releases/> before the defense!
> - Bonus: Redis, FTP (vsftpd), static website, Adminer, and the free choice
>   **Prometheus + Blackbox Exporter** (monitoring, no host access).
> - Secrets: **Docker secrets** for passwords, `.env` for non-secret configuration (doc 05).

## Suggested reading order

| # | File | Answers |
|---|------|---------|
| 01 | [requirements-checklist](01-requirements-checklist.md) | What exactly is demanded and how it will be checked |
| 02 | [virtualization-and-vm](02-virtualization-and-vm.md) | VM, hypervisor, VirtualBox, Packer, preseed, Vagrant |
| 03 | [docker-fundamentals](03-docker-fundamentals.md) | Images, containers, layers, Dockerfile, PID 1, daemons |
| 04 | [docker-compose](04-docker-compose.md) | Services, networks, volumes, secrets, healthchecks, restart |
| 05 | [secrets-env-networks-volumes](05-secrets-env-networks-volumes.md) | The four comparisons required in the README |
| 06 | [nginx-and-tls](06-nginx-and-tls.md) | NGINX, reverse proxy, TLS 1.2/1.3, self-signed certs |
| 07 | [wordpress-php-fpm](07-wordpress-php-fpm.md) | WordPress, PHP-FPM, FastCGI, WP-CLI |
| 08 | [mariadb](08-mariadb.md) | MariaDB, initialization, users, root password |
| 09 | [shell-and-make](09-shell-and-make.md) | POSIX sh, `set -eu`, `exec "$@"`, heredocs, envsubst, GNU Make |
| 10 | [bonus-services](10-bonus-services.md) | Redis, vsftpd, static site, Adminer, Prometheus + Blackbox (+ how risky other tools are) |
| 11 | [reference-walkthrough](11-reference-walkthrough.md) | File-by-file explanation of `acaceres_inception` |
| 12 | [defense-prep](12-defense-prep.md) | The eval sheet, question by question, with commands |
| 13 | [build-roadmap](13-build-roadmap.md) | In which order to fill the skeleton files |

## How every tool page is organized

1. **What is it?** — one-paragraph definition.
2. **Why do we use it here?** — the requirement or problem it solves.
3. **How does it work?** — the mental model you must be able to draw.
4. **In our project** — which file(s) use it.
5. **Key commands / directives** — what you will actually type.
6. **Pitfalls** — things that fail evaluations.
7. **Official documentation** — links to read later.

## Golden rule (from the subject's AI chapter)

> "Only use AI-generated content that you fully understand and can take
> responsibility for."

The skeleton files under `srcs/`, `vm/`, `Makefile`… contain only comments. You
write the real content, line by line, once you can explain it.
