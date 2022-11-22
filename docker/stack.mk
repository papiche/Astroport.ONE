COMPOSE_FILE_VDI                := true
COMPOSE_PROJECT_NAME            := $(HOSTNAME)
MAKE_VARS                       += NODE_VDI_PORT node
SERVICE                         := astroport
SSH_PORT                        := $(NODE_VDI_PORT)
SSH_PUBLIC_HOSTS                += git.p2p.legal
STACK                           := node
UFW_UPDATE                      := $(SERVICE)
node                            := node/ipfs

bootstrap-stack: myos-node

