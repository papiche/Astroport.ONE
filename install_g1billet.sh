#!/bin/bash
        ## INSTALL G1BILLET
        echo "INSTALLING G1BILLET SERVICE : http://g1billet.localhost:33101"
        if [[ ! -d ~/.zen/G1BILLET ]]; then
            mkdir -p ~/.zen
            cd ~/.zen
            git clone https://git.p2p.legal/qo-op/G1BILLET.git
            cd G1BILLET && ./setup_systemd.sh
            cd -
        fi
