#########################################################
##
## install commands
##
#########################################################
distro := $(shell lsb_release -is)


check-distro: ## check distro
	@echo $(distro)


ifeq ($(distro),Ubuntu)
    ANSIBLE_APT_ADD_REPO := sudo apt-add-repository ppa:ansible/ansible -y
    YQ_APT_ADD_REPO 	 := sudo apt-add-repository ppa:rmescandon/yq -y
else
    YQ_APT_ADD_REPO      :=
    ANSIBLE_APT_ADD_REPO :=
endif

ifneq ("$(wildcard ./etc/traefik/letsencrypt/acme.json)","")
    BUILD_DEPENDENCIES += fix-acme-json-permissions
endif

fix-acme-json-permissions:
	sudo chmod 600 ./etc/traefik/letsencrypt/acme.json

build: install-dependencies environments-enabled/onramp.env $(BUILD_DEPENDENCIES)

install: build install-docker

environments-enabled/onramp.env:
	@clear
	@echo "***********************************************"
	@echo "Traefik Turkey OnRamp Setup"
	@echo "***********************************************"
	@echo ""
	@echo "Welcome to OnRamp - Traefik with all the stuffing."
	@echo ""
	@echo ""
	@echo "To proceed with the initial setup you will need to "
	@echo "provide some information that is required for"
	@echo "OnRamp to function properly."
	@echo ""
	@echo "Required information:"
	@echo ""
	@echo "--> Cloudflare Email Address"
	@echo "--> Cloudflare Access Token"
	@echo "--> Hostname of system OnRamp is running on."
	@echo "--> Domain for which traefik will be handling requests"
	@echo "--> Timezone"
	@echo ""
	@echo ""
	@echo ""
	@python3 scripts/env-subst.py environments-available/onramp.template "ONRAMP"

EXECUTABLES = git nano jq yq pip yamllint
MISSING_PACKAGES := $(foreach exec,$(EXECUTABLES),$(if $(shell which $(exec)),,addpackage-$(exec)))

addrepositories:
	$(YQ_APT_ADD_REPO)
	sudo apt update

addpackage-%: addrepositories
	DEBIAN_FRONTEND=noninteractive sudo apt install $* -y

install-dependencies: .gitconfig $(MISSING_PACKAGES)

.gitconfig:
	git config -f .gitconfig core.hooksPath .githooks
	git config --local include.path $(shell pwd)/.gitconfig

install-ansible:
	#sudo apt-add-repository ppa:ansible/ansible -y
	$(APT_ADD_REPO)	
	sudo apt update
	sudo apt install ansible -y
	@echo "Installing ansible roles requirements..."
	ansible-playbook ansible/ansible-requirements.yml

install-docker: install-ansible
	ansible-playbook ansible/install-docker.yml

install-node-exporter: install-ansible
	ansible-playbook ansible/install-node-exporter.yml

install-nvidia-drivers: install-ansible
	ansible-playbook ansible/install-nvidia-drivers.yml
