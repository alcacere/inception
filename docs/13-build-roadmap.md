# 13 — Build roadmap (in which order to fill the skeleton)

Each skeleton file contains only comments: **PURPOSE**, **WHY**, **WRITE** (steps), **CHECK**
(how to test it), **READ** (which doc). Replace the comments with real content
once you can explain every line. Keep short comments that help *you* in the defense.

## Phase 0: host prerequisites
- [ ] Fix VirtualBox: `sudo /sbin/vboxconfig` (the vboxdrv module isn't loaded for kernel 7.0.0-38).
- [ ] Install Packer (single binary in `~/bin`, no sudo needed): <https://developer.hashicorp.com/packer/install>
- [ ] `git init` the project and commit the skeleton.

## Phase 1: the VM (docs 02)
1. `vm/packer/http/preseed.cfg`: get a Debian install that finishes with no questions (watch it with `headless=false`).
2. `vm/packer/variables.pkr.hcl` + `vm/packer/inception.pkr.hcl`: `packer validate`, then `packer build`.
3. `vm/packer/scripts/provision.sh` + `cleanup.sh`: Docker installed, the user is in the docker group, and `/etc/hosts` has the domain.
4. `vm/Vagrantfile` + `vm/scripts/*.sh`: `vagrant up`, then `vagrant ssh`, then `docker run --rm hello-world`.
5. Root `Makefile` `vm-*` targets.
✔ Milestone: one command (`make vm`) goes from nothing to a VM with Docker.

## Phase 2: mandatory stack (docs 03–09)
Build **one service at a time**, testing each with `docker compose up --build <service>`:
1. `.gitignore`, `srcs/.env.example`, `srcs/requirements/tools/generate-secrets.sh`, `check-env.sh`.
2. **MariaDB**: Dockerfile, conf, entrypoint. Test: login as root without a password fails, and the user works.
3. **WordPress**: Dockerfile, www.conf, entrypoint. Test: `wp core is-installed`, and the healthcheck is healthy.
4. **NGINX**: Dockerfile, nginx.conf, template, entrypoint. Test: TLS 1.2/1.3 OK, 1.1 fails, port 80 refused.
5. `docker-compose.yml` with networks, named volumes in `/home/alcacere/data`, secrets, healthchecks, restart.
6. Root `Makefile` targets (all, down, clean, fclean, re…).
7. Run **all of doc 12** from a fresh clone + the cleanup command + a VM reboot.
✔ Milestone: `git tag mandatory-ok`. Don't touch the bonus until this is perfect.

## Phase 3: bonus (doc 10)
Redis → Adminer → static website → FTP → Blackbox Exporter → Prometheus. After each one, run the
mandatory tests again (regressions kill the bonus).


## Phase 4: required docs
`README.md`, `USER_DOC.md`, `DEV_DOC.md`, in English, with every required section (doc 01).

## Phase 4.5: clean the skeleton comments
Some skeleton comments contain the literal forbidden words as warnings (`--link`,
`tail -f`, `sleep infinity` in `Makefile`, `provision.sh`, the MariaDB entrypoint). An
evaluator who greps them could stop the evaluation by mistake. Before submitting, remove those
words from the comments and check:
`grep -rnE "tail -f|sleep infinity|--link|while true" --exclude-dir=docs .` must print nothing.

## Phase 5: defense rehearsal
Explain each file out loud to a peer (the subject insists on peer review). Practice the live modifications.
