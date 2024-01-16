#!/bin/bash
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

for i in gcc python3-pip python3-setuptools libpq-dev python3-dev python3-wheel python3-duniterpy python3-termcolor  ; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        [[ ! $j ]] && sudo apt update
        sudo apt install -y $i
        j=1
    fi
done

python -m pip install -r requirements.txt

## INSTALL SYSTEM WIDE
mkdir -p ~/.local/bin/

cp ${MY_PATH}/jaklis.py ~/.local/bin/jaklis
cp ${MY_PATH}/.env ~/.local/bin/
chmod u+x ~/.local/bin/jaklis
