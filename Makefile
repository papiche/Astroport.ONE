MYOS                            ?= ../myos
MYOS_REPOSITORY                 ?= https://github.com/aynicos/myos
-include $(MYOS)/make/include.mk
$(MYOS):
	-@git clone $(MYOS_REPOSITORY) $(MYOS)

.PHONY: all install shellcheck shellcheck-% tests
SHELL_FILES ?= $(wildcard .*/*.sh */*.sh */*/*.sh)

all: install tests

player:
	$(call make,stack-ipfs-$(if $(DELETE),down,up) USER=$(PLAYER),$(MYOS),IPFS_IDENTITY_PEERID IPFS_IDENTITY_PRIVKEY)

tests: shellcheck

shellcheck:
	shellcheck $(SHELL_FILES) ||:

shellcheck-%:
	shellcheck $*/*.sh
