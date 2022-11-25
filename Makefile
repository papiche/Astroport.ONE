MYOS                            ?= ../myos
MYOS_REPOSITORY                 ?= https://github.com/aynicos/myos
-include $(MYOS)/make/include.mk
$(MYOS):
	-@git clone $(MYOS_REPOSITORY) $(MYOS)

.PHONY: all install shellcheck shellcheck-% tests
SHELL_FILES ?= $(wildcard .*/*.sh */*.sh */*/*.sh)

all: install tests

install: myos-node player-build up

player: STACK := User
player:
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
