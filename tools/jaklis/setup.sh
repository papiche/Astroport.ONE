#!/bin/bash

for i in gcc python3-pip python3-setuptools libpq-dev python3-dev python3-wheel python3-duniterpy python3-termcolor  ; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        [[ ! $j ]] && sudo apt update
        sudo apt install -y $i
        j=1
    fi
done

~/.venvs/astro/bin/python -m pip install -r requirements.txt

sed "s~/usr/bin/env python3~$HOME/.venvs/astro/bin/python~g" jaklis.py > ~/.local/bin/
chmod u+x ~/.local/bin/jaklis.py
