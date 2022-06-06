#!/bin/bash
################################################################################
source ./header.sh

player=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)
moa=$(ipfs key list -l | grep -w moa_$PLAYER | cut -d ' ' -f 1)

qoop=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)

xdg-open "http://127.0.0.1:8080/ipns/$player"
