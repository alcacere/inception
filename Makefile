# **************************************************************************** #
#  Makefile (repo root)                                       READ: docs/09, 04 #
# **************************************************************************** #
#
# PURPOSE
#   The single entry point for the evaluator. Subject: "It must set up your
#   entire application (i.e., it has to build the Docker images using
#   docker-compose.yml)". It runs INSIDE the VM (the vm-* targets run on the host).
#
# WHY A MAKEFILE
#   Short, memorable commands (make, make down, make fclean...) that hide the long
#   `docker compose -f srcs/docker-compose.yml --env-file srcs/.env ...` lines
#   and guarantee the steps run in the right order (dirs → checks → build → up).
#
# WRITE (variables)
#   - LOGIN      = alcacere
#   - DATA_DIR   = /home/$(LOGIN)/data   (subject: volumes stored here)
#   - COMPOSE    = docker compose -f srcs/docker-compose.yml --env-file srcs/.env
#     (optionally add -p inception so names are stable)
#
# WRITE (targets), each one in .PHONY
#   all       default goal (FIRST target in the file) → depends on `up`
#   up        prerequisites: `check` + data dirs; then $(COMPOSE) up -d --build
#   build     $(COMPOSE) build
#   down      $(COMPOSE) down (containers + networks; data kept)
#   stop/start  pause and resume without removing containers
#   ps / logs   $(COMPOSE) ps   /   $(COMPOSE) logs -f
#   secrets   call srcs/requirements/tools/generate-secrets.sh
#             (creates missing secrets/*.txt, copies .env.example → .env if missing)
#   check     call srcs/requirements/tools/check-env.sh (fail early with a clear
#             message if .env / secrets are missing or the admin name contains "admin")
#   dirs      mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress (+ bonus volumes)
#             → MUST exist before `up` (local driver + o: bind fails otherwise)
#   clean     down + remove the images built by the project
#   fclean    clean + down -v (volumes) + delete $(DATA_DIR)
#             (files belong to container UIDs → think about how to delete them:
#              sudo, or a throwaway `docker run --rm -v ... alpine:3.23 rm -rf ...`)
#   re        fclean then all
#
#   (optional) bonus   if you use compose profiles: $(COMPOSE) --profile bonus up -d --build
#
.PHONY: vm-box vm vm-ssh vm-destroy

secrets:
	./srcs/requirements/tools/generate-secrets.sh

vm-box:
	./vm/scripts/build-box.sh

vm:
	./vm/scripts/up.sh

vm-reload:
	cd vm && vagrant reload

vm-ssh:
	cd vm && vagrant ssh

vm-destroy:
	./vm/scripts/destroy.sh

#
# ☠ FORBIDDEN: never use --link anywhere. Eval greps the Makefile and scripts.
#
# CHECK
#   - fresh `git clone` + `make secrets` + `make` works with no manual edit
#   - `make re` works twice in a row
#   - `make` after a VM reboot keeps all the WordPress data
