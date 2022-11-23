MYOS                            ?= ../myos
MYOS_REPOSITORY                 ?= https://github.com/aynicos/myos
-include $(MYOS)/make/include.mk
$(MYOS):
	-@git clone $(MYOS_REPOSITORY) $(MYOS)

.PHONY: all install shellcheck shellcheck-% tests
SHELL_FILES ?= $(wildcard .*/*.sh */*.sh */*/*.sh)

all: install tests

tests: shellcheck

shellcheck:
	shellcheck $(SHELL_FILES) ||:

shellcheck-%:
	shellcheck $*/*.sh
