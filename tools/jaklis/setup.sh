#!/bin/bash
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
hasError=0

for i in gcc python3-pip python3-setuptools libpq-dev python3-dev python3-wheel; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        [[ ! $j ]] && sudo apt update
        sudo apt install -y $i
        j=1
    fi
done

pip3 install --break-system-packages -r requirements.txt || hasError=1
chmod u+x jaklis.py
sudo ln -sf $(realpath jaklis.py) /usr/local/bin/jaklis || hasError=1
sudo cp ${MY_PATH}/.env /usr/local/bin/ || hasError=1

if [[ hasError -eq 0 ]]; then
    echo "Setup done. You can use 'jaklis' command, try it."
else
    echo "An error has occurred"
fi
