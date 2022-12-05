MYOS                            ?= ../myos
MYOS_REPOSITORY                 ?= https://github.com/aynicos/myos
-include $(MYOS)/make/include.mk
$(MYOS):
	-@git clone $(MYOS_REPOSITORY) $(MYOS)

.PHONY: all install shellcheck shellcheck-% tests
SHELL_FILES ?= $(wildcard .*/*.sh */*.sh */*/*.sh)

all: install tests

install: upgrade build myos-host up player

upgrade: migrate-ipfs migrate-zen
	echo "Welcome to myos docker land - make a user - make a player -"

migrate-%:
	[ ! -f /var/lib/docker/volumes/$(HOSTNAME)_$*/_data ] \
	&& $(RUN) $(SUDO) mkdir -p /var/lib/docker/volumes/$(HOSTNAME)_$*/_data \
	&& $(RUN) $(SUDO) cp -a ~/.$* /var/lib/docker/volumes/$(HOSTNAME)_$*/_data \
	&& $(RUN) $(SUDO) chown -R $(USER) /var/lib/docker/volumes/$(HOSTNAME)_$* \
	|| :

player: STACK := User
player: docker-network-create-$(USER)
	$(call make,stack-User-$(if $(DELETE),down,up),$(MYOS),COMPOSE_PROJECT_NAME MAIL)

player-%: STACK := User
player-%:
	$(if $(filter $*,$(filter-out %-%,$(patsubst docker-compose-%,%,$(filter docker-compose-%,$(MAKE_TARGETS))))), \
	  $(call make,stack-User-$*,$(MYOS),COMPOSE_PROJECT_NAME MAIL) \
	)

tests: shellcheck

shellcheck:
	shellcheck $(SHELL_FILES) ||:

shellcheck-%:
	shellcheck $*/*.sh
