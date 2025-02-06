#!/bin/bash
## INSTALL UPassport
echo "INSTALLING UPassport API : http://localhost:54321"
if [[ ! -d ~/.zen/UPassport ]]; then
    mkdir -p ~/.zen
    cd ~/.zen
    git clone https://github.com/papiche/UPassport.git
    cd UPassport && ./setup_systemd.sh
    cd -
fi
