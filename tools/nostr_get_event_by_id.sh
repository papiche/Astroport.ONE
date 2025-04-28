#!/bin/bash
# get_event_by_id

event_id="$1"
cd $HOME/.zen/strfry
# Use strfry scan with a filter for the specific event ID
./strfry scan '{"ids":["'"$event_id"'"]}' 2>/dev/null
cd - 1>&2>/dev/null

exit 0
