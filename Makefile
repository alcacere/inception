LOGIN       ?= alcacere
DATA_DIR    ?= /home/$(LOGIN)/data
COMPOSE     := docker compose -f srcs/docker-compose.yml --env-file srcs/.env -p inception

.DEFAULT_GOAL := all

all: up

# setup volumes and secrets target

dirs:
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

secrets: 
	@./srcs/requirements/tools/generate-secrets.sh

check: secrets
	@./srcs/requirements/tools/check-env.sh

# compose targets

build: dirs check
	$(COMPOSE) build

up: dirs check
	$(COMPOSE) up -d --build

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
		sudo rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress; \
	fi

re: fclean all

# vm targets

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

.PHONY: all up build down start stop ps logs dirs secrets check clean fclean re \
        vm-box vm vm-reload vm-ssh vm-destroy