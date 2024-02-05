MYOS                                      ?= ../myos
MYOS_REPOSITORY                           ?= $(patsubst %/$(APP),%/myos,$(APP_REPOSITORY))
APP                                       ?= $(lastword $(subst /, ,$(APP_REPOSITORY)))
APP_REPOSITORY                            ?= $(shell git config --get remote.origin.url 2>/dev/null)
-include $(MYOS)/make/include.mk
$(MYOS):
	-@git clone $(MYOS_REPOSITORY) $(MYOS)

SHELL_FILES ?= $(wildcard .*/*.sh */*.sh */*/*.sh)

.PHONY: all
all: install tests

.PHONY: install
install: myos build player up
	echo "Welcome to myos docker land - make a user - make a player -"

.PHONY: migrate
migrate-%: home                           := ~/.zen/game/players
migrate-%:
	if $(SUDO) test ! -d /var/lib/docker/volumes/$(HOSTNAME)_$*; then \
	  $(RUN) $(SUDO) mkdir -p /var/lib/docker/volumes/$(HOSTNAME)_$* \
	   && $(RUN) $(SUDO) cp -a $(if $($*),$($*)/,~/.$*/) /var/lib/docker/volumes/$(HOSTNAME)_$*/_data \
	   && $(RUN) $(SUDO) chown -R $(HOST_UID):$(HOST_GID) /var/lib/docker/volumes/$(HOSTNAME)_$*/_data \
	  ; \
	fi

.PHONY: player
player: STACK                             := User
player: docker-network-create-$(USER)
	$(call make,stack-User-$(if $(DELETE),down,up),$(MYOS),$(PLAYER_MAKE_VARS))

.PHONY: player-%
player-%: STACK                           := User
player-%:
	$(if $(filter $*,$(filter-out %-%,$(patsubst docker-compose-%,%,$(filter docker-compose-%,$(MAKE_TARGETS))))), \
	  $(call make,stack-User-$*,$(MYOS),$(PLAYER_MAKE_VARS)) \
	)

.PHONY: upgrade
upgrade: migrate-home migrate-ipfs install

## TESTS

.PHONY: check
check:
	shellcheck $(SHELL_FILES) ||:

.PHONY: shellcheck-%
shellcheck-%:
	shellcheck $*/*.sh

.PHONY: shellspec
specs: shellspec-specs;

.PHONY: shellspec-%
shellspec-%:
	shellspec -f tap $*

.PHONY: tests
tests: check specs
