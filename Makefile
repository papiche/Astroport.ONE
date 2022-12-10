MYOS                            ?= ../myos
MYOS_REPOSITORY                 ?= https://github.com/aynicos/myos
-include $(MYOS)/make/include.mk
$(MYOS):
	-@git clone $(MYOS_REPOSITORY) $(MYOS)

SHELL_FILES ?= $(wildcard .*/*.sh */*.sh */*/*.sh)

.PHONY: all
all: install tests

.PHONY: install
install: upgrade build myos up player

.PHONY: migrate
migrate-%: home := ~/.zen/game/players
migrate-%:
	[ ! -d /var/lib/docker/volumes/$(HOSTNAME)_$* ] \
	&& $(RUN) $(SUDO) mkdir -p /var/lib/docker/volumes/$(HOSTNAME)_$* \
	&& $(RUN) $(SUDO) cp -a $(if $($*),$($*)/,~/.$*/) /var/lib/docker/volumes/$(HOSTNAME)_$*/_data \
	&& $(RUN) $(SUDO) chown -R $(HOST_UID):$(HOST_GID) /var/lib/docker/volumes/$(HOSTNAME)_$*/_data \
	|| :

.PHONY: player
player: STACK := User
player: docker-network-create-$(USER)
	$(call make,stack-User-$(if $(DELETE),down,up),$(MYOS),COMPOSE_PROJECT_NAME MAIL)

.PHONY: player-%
player-%: STACK := User
player-%:
	$(if $(filter $*,$(filter-out %-%,$(patsubst docker-compose-%,%,$(filter docker-compose-%,$(MAKE_TARGETS))))), \
	  $(call make,stack-User-$*,$(MYOS),COMPOSE_PROJECT_NAME MAIL) \
	)

.PHONY: shellcheck
shellcheck:
	shellcheck $(SHELL_FILES) ||:

.PHONY: shellcheck-%
shellcheck-%:
	shellcheck $*/*.sh

.PHONY: tests
tests: shellcheck

.PHONY: upgrade
upgrade: migrate-home migrate-ipfs
	echo "Welcome to myos docker land - make a user - make a player -"
