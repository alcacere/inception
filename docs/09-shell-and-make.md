# 09 — Shell scripting and GNU Make (the automation glue)

## POSIX sh (BusyBox ash on Alpine)

**What?** The standard Unix shell language. Alpine has no bash by default:
`/bin/sh` is BusyBox **ash**, so write portable POSIX sh. No `[[ ]]`, no arrays, no
`function` keyword, no `source` (use `.`).

**Why?** Entrypoint scripts do the runtime setup that can't happen at build
time: read secrets, initialize the DB on first run, render configs from env,
then hand over to the real service.

### Building blocks you'll use

| Construct | Meaning / why |
|-----------|---------------|
| `#!/bin/sh` | Interpreter line. The script must also be executable (`chmod +x`) |
| `set -e` | Exit on the first failing command, so a half-configured container doesn't keep running |
| `set -u` | Error on undefined variables (catches a missing env var) |
| `exec "$@"` | Replace the shell by the CMD arguments, so the service becomes **PID 1** |
| `"$@"` vs `$*` | `"$@"` keeps each argument separate and correctly quoted |
| `[ -f file ]`, `[ -d dir ]`, `[ -z "$v" ]`, `[ -n "$v" ]` | Tests (idempotency: "already initialized?") |
| `$(cat /run/secrets/x)` | Command substitution: read a secret into a variable |
| `${VAR:?msg}` | Abort with a message if VAR is unset/empty |
| `cat <<EOF ... EOF` | **Heredoc**: multi-line input (SQL, config) with variable expansion |
| `<<'EOF'` | Quoted heredoc: **no** expansion |
| `cmd > /dev/null 2>&1` | Silence stdout and stderr |
| `trap 'cleanup' EXIT` | Run cleanup on exit |

### Idempotency
Every script must be safe to run **every start**: first run → install; later
runs → skip and just `exec` the service. Test: `docker compose restart` and VM
reboot must not reinstall or fail.

### ☠ Forbidden in scripts
`tail -f`, `sleep infinity`, `while true`, starting the final service with `&`.
A bounded wait (`i=0; while [ $i -lt 30 ]; do ...; i=$((i+1)); done`) is not an
infinite loop, but prefer compose healthchecks so you don't need it.

### envsubst
From GNU gettext (`apk add gettext`). It replaces `${VAR}` in a template with env values:
```
envsubst '${DOMAIN_NAME} ${NGINX_PORT}' < site.conf.template > site.conf
```
**Always pass the variable list**. Otherwise it also replaces nginx's own `$uri`, `$args`… with empty strings.

**Docs**
- POSIX Shell Command Language: <https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html>
- `set` builtin (POSIX): <https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html#set>
- Bash manual (good explanations, but mind the bash-only features): <https://www.gnu.org/software/bash/manual/bash.html>
- ShellCheck, a linter (run it on every script): <https://www.shellcheck.net/>
- envsubst: <https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html>
- BusyBox commands: <https://busybox.net/downloads/BusyBox.html>

---

## GNU Make

**What?** A build-automation tool. A `Makefile` declares **targets**, their
**prerequisites** and the **recipe** (shell commands, indented with a **TAB**).

**Why?** The subject requires a root Makefile that sets up the whole app. It's the
single entry point for the evaluator: `make`.

```make
NAME    = inception
COMPOSE = docker compose -f srcs/docker-compose.yml --env-file srcs/.env

all: up                         # first target = default goal
up: check dirs
	$(COMPOSE) up -d --build
.PHONY: all up down clean fclean re
```

**Key concepts**
- `.PHONY`: the target is not a file, so it always runs.
- Variables: `=` (recursive), `:=` (immediate), `?=` (default if unset).
- Each recipe line runs in a **new shell**. Use `\` to continue a line, and `$$` for a shell `$`.
- `@` hides the command echo, and `-` ignores errors.
- `$(MAKE)` for recursive calls.

**Targets we plan** (see `Makefile` skeleton): `all/up`, `build`, `down`,
`stop/start`, `logs`, `ps`, `secrets`, `check`, `clean`, `fclean`, `re`, `vm-*`.

**Docs**
- GNU Make manual: <https://www.gnu.org/software/make/manual/make.html>
- Phony targets: <https://www.gnu.org/software/make/manual/make.html#Phony-Targets>
- Recipe syntax: <https://www.gnu.org/software/make/manual/make.html#Recipes>

---

## openssl rand (secrets generation)

`openssl rand -base64 24` or `openssl rand -hex 16` generates a random password. A
`make secrets` target that creates the missing `secrets/*.txt` files lets the
project run from a fresh clone **without credentials in Git**. Use `umask 077` /
`chmod 600` so the files aren't world-readable.

**Docs:** <https://docs.openssl.org/3.0/man1/openssl-rand/>
