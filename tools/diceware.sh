#!/usr/bin/env bash
# Download the wordlist
# wget -nc -O ~/.diceware-wordlist http://world.std.com/%7Ereinhold/diceware.wordlist.asc 2> /dev/null
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
MOTS=$(echo "$1" | grep -E "^\-?[0-9]+$")
# Default to 6 words passphrase
if [[ "$MOTS" == "" ]]; then MOTS=6; fi
WORDCOUNT=${1-$MOTS}
# print a list of the diceware words
cat ${MY_PATH}/diceware-wordlist.txt |
awk '/[1-6][1-6][1-6][1-6][1-6]/{ print $2 }' |
# randomize the list order
shuf --random-source=/dev/urandom |
# pick the first n words
head -n ${WORDCOUNT} |
# pretty print
tr '\n' ' '
echo
