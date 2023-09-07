COMPOSE_IGNORE_ORPHANS                    := true
DOCKER_IMAGES_MYOS                        := $(if $(COMPOSE_FILE_VDI),x2go:xfce-debian)
ENV_VARS                                  += HOST_ASTROPORT_SERVICE_1234_TAGS
HOST_ASTROPORT_SERVICE_NAME               ?= astroport
HOST_ASTROPORT_SERVICE_1234_TAGS          ?= $(call tagprefix,HOST_ASTROPORT,1234)
HOST_ASTROPORT_UFW_UPDATE                 := 1234/tcp 12245:12445/tcp 45720/tcp
MAKE_VARS                                 += SSH_PORT User host
PLAYER_MAKE_VARS                          := COMPOSE_PROJECT_NAME MAIL IPFS_UFW_DOCKER IPFS_UFW_UPDATE USER_IPFS_SERVICE_PROXY_TCP USER_IPFS_SERVICE_5001_ENVS RESU_HOME RESU_HOST
RESU_HOME                                 := mail
RESU_HOST                                 := true
SERVICE                                   := astroport
SSH_PORT                                  := 45720
SSH_PUBLIC_HOSTS                          := git.p2p.legal
STACK                                     := host
User                                      := User/ipfs
host                                      := host/ipfs
ifeq ($(PLAYER_API_ONLINE),true)
USER_IPFS_SERVICE_5001_ENVS               ?= 5001
else ifneq ($(PLAYER_API_PORT),)
IPFS_UFW_DOCKER                           += 5001/tcp
IPFS_UFW_UPDATE                           += $(PLAYER_API_PORT)/tcp
USER_IPFS_SERVICE_PROXY_TCP               := :$(PLAYER_API_PORT)
USER_IPFS_SERVICE_5001_ENVS               += proxy
endif
