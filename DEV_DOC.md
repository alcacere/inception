<!--
DEV_DOC.md (required by subject chapter VII)                  READ: docs/01, 02, 04

AUDIENCE: a developer who wants to rebuild or modify the project.

MUST DESCRIBE HOW TO:
  1. Set up the environment from scratch
     - host prerequisites (VirtualBox, Packer, Vagrant), make vm
     - configuration files (srcs/.env from .env.example: every variable explained)
     - secrets (list of secrets/*.txt files, which service uses each one)
  2. Build and launch with the Makefile and Docker Compose
     (what each make target does, which compose command it runs)
  3. Use relevant commands to manage containers and volumes
     (docker compose ps/logs/exec/config, docker volume ls/inspect,
      docker network inspect, rebuilding a single service)
  4. Identify where the project data is stored and how it persists
     (named volumes → /home/alcacere/data/{mariadb,wordpress,...},
      why they survive `down` and reboots, what `fclean` deletes)

GOOD EXTRAS: directory tree explained, startup order (healthcheck DAG),
how to add a new service.
-->
