#!/bin/bash
# stop old logging process
killall tail
killall journalctl

# display log files
# Astroport
journalctl -fu astroport &
tail -f ~/.zen/tmp/IA.log &
tail -f ~/.zen/tmp/12345.log &
tail -f ~/.zen/tmp/_12345.log &

# NOSTR relay
journalctl -fu strfry &
tail -f ~/.zen/tmp/uplanet_messages.log &
tail -f ~/.zen/tmp/strfry.log &
tail -f ~/.zen/tmp/nostr_likes.log &
tail -f ~/.zen/tmp/nostpy.log &

## UPassport API
journalctl -fu upassport &
tail -f ~/.zen/tmp/54321.log &
