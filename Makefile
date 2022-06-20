# include .env variable in the current environment
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# any disabled-*.yml docker-compose files will be ignored
disabled_files := $(wildcard services-enabled/disabled-*.yml)
# all other *.yml files in the current directory will be included 
# when running make commands that call docker compose
compose_files := $(filter-out $(disabled_files), $(wildcard services-enabled/*.yml)) 
args := -f docker-compose.yml $(foreach file, $(compose_files), -f $(file))

# get the boxes ip address and the current users id and group id
export HOSTIP := $(shell ip route get 1.1.1.1 | grep -oP 'src \K\S+')
export PUID 	:= $(shell id -u)
export PGID 	:= $(shell id -g)
export HOST_NAME := $(or $(HOST_NAME), $(shell hostname))

# check if we should use docker-compose or docker compose
ifeq (, $(shell which docker-compose))
	DOCKER_COMPOSE := docker compose
else
	DOCKER_COMPOSE := docker-compose
endif

# this is the default target run if no other targets are passed to make
# i.e. if you just type: make
start: 
	$(DOCKER_COMPOSE) $(args) up -d --force-recreate

up: 
	$(DOCKER_COMPOSE)$(args) up --force-recreate

down: 
	$(DOCKER_COMPOSE) $(args) down

start-staging:
	ACME_CASERVER=https://acme-staging-v02.api.letsencrypt.org/directory $(DOCKER_COMPOSE) $(args) up -d --force-recreate
	@echo "waiting 30 seconds for cert DNS propogation..."
	@sleep 30
	@echo "open https://$(HOST_NAME).$(HOST_DOMAIN)/traefik in a browser"
	@echo "and check that you have a staging cert from LetsEncrypt!"
	@echo "if you don't get the write cert run the following command and look for error messages:"
	@echo "$(DOCKER_COMPOSE) logs | grep acme"

down-staging:
	$(DOCKER_COMPOSE) $(args) down
	@echo "cleaning up staging certificates"
	sudo rm etc/letsencrypt/acme.json

clean:
	sudo rm etc/letsencrypt/acme.json

pull:
	$(DOCKER_COMPOSE) $(args) pull

logs:
	$(DOCKER_COMPOSE)  $(args) logs -f

restart: down start

update: down pull start

echo:
	@echo $(args)

env:
	env | sort