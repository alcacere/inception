LOGIN       ?= alcacere
DATA_DIR    ?= /home/$(LOGIN)/data
COMPOSE     := docker compose -f srcs/docker-compose.yml --env-file srcs/.env -p inception

.DEFAULT_GOAL := all

all: up

# setup volumes and secrets target

dirs:
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress $(DATA_DIR)/certs $(DATA_DIR)/prometheus
	@sudo chmod -R 777 $(DATA_DIR)/prometheus 2>/dev/null || true

secrets: 
	@./srcs/requirements/tools/generate-secrets.sh

check: secrets
	@./srcs/requirements/tools/check-env.sh

# compose targets

build: dirs check
	$(COMPOSE) build

up: dirs check
	$(COMPOSE) up -d --build
	@if [ -f "$(DATA_DIR)/certs/rootCA.crt" ]; then \
		sudo cp $(DATA_DIR)/certs/rootCA.crt /usr/local/share/ca-certificates/inception-rootCA.crt 2>/dev/null && \
		sudo update-ca-certificates >/dev/null 2>&1 || true; \
	fi

down:
	$(COMPOSE) down

start: 
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

ps:
	$(COMPOSE) ps

logs: 
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down --rmi local --remove-orphans

fclean:
	$(COMPOSE) down -v --rmi all --remove-orphans
	@if [ -d "$(DATA_DIR)" ]; then \
		echo "cleaning $(DATA_DIR)..."; \
		sudo rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress $(DATA_DIR)/certs $(DATA_DIR)/prometheus; \
	fi

re: fclean all

# vm targets

cluster:
	@./vm/scripts/cluster-setup.sh

vm-box:
	./vm/scripts/build-box.sh

vm:
	./vm/scripts/up.sh

vm-rsync:
	cd vm && vagrant rsync

vm-auto-rsync:
	cd vm && vagrant rsync-auto

vm-reload:
	cd vm && vagrant reload

vm-suspend:
	cd vm && vagrant suspend

vm-resume:
	cd vm && vagrant resume

vm-ssh:
	cd vm && vagrant ssh

vm-destroy:
	./vm/scripts/destroy.sh

.PHONY: all up build down start stop ps logs dirs secrets check clean fclean re \
        cluster vm-box vm vm-reload vm-ssh vm-destroy
