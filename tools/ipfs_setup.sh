#!/bin/bash
########################################################################
{ # this ensures the entire script is downloaded #
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

# CHECK not root user !!
if [ "$EUID" -eq 0 ]
  then echo -e "DO NOT EXECUTE AS root. Choose a user for your Astroport Station (we like pi)"
  exit 1
else echo -e "OK $USER, let's go!";
fi

# Ask user password on start
sudo true

## Error funciton
err() {
    echo -e "ERREUR: $1"
    exit 1
}

# CHECK node IP isLAN?
myIP=$(hostname -I | awk '{print $1}')
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);

MACHINE_TYPE=`uname -m`

# CHECK if daemon is already running
if [[ $YOU ]]; then
    echo "ipfs daemon already running...! Run by $YOU $MACHINE_TYPE"
    [[ $YOU == $USER]] && echo "Stopping ipfs daemon" && killall ipfs \
                                        || (echo "ERROR $YOU is running ipfs, must be $USER" && exit 1)
else
    # INIT ipfs
    if [[ ! -d ~/.ipfs ]]; then
    [[ $isLAN ]] && ipfs init -p lowpower \
    || ipfs init -p server
    fi
fi

echo -e "Astroport activate IPFS Layer installation..."

    ## DEBIAN
    echo "CREATE SYSTEMD ipfs SERVICE >>>>>>>>>>>>>>>>>>"
cat > /tmp/ipfs.service <<EOF
[Unit]
Description=IPFS daemon
After=network.target
Requires=network.target

[Service]
Type=simple
User=_USER_
RestartSec=1
Restart=always
Environment=IPFS_FD_MAX=8192
ExecStart=/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesys-pubsub
CPUAccounting=true
CPUQuota=60%

[Install]
WantedBy=multi-user.target
EOF

sudo cp -f /tmp/ipfs.service /etc/systemd/system/
sudo sed -i "s/_USER_/$USER/g" /etc/systemd/system/ipfs.service

sudo systemctl daemon-reload
sudo systemctl enable ipfs

###########################################
# ACTIVATE IPFS OPTIONS: #swarm0 INIT
###########################################
### IMPORTANT !!!!!!! IMPORTANT !!!!!!
###########################################
# DHT PUBSUB mode
ipfs config Pubsub.Router gossipsub

# MAXSTORAGE = 1/2 available
availableDiskSize=$(df -P ~/ | awk 'NR>1{sum+=$4}END{print sum}')
diskSize="$((availableDiskSize / 2))"
ipfs config Datastore.StorageMax $diskSize

## Activate Rapid "ipfs p2p"
ipfs config --json Experimental.Libp2pStreamMounting true
ipfs config --json Experimental.P2pHttpProxy true
ipfs config --json Swarm.ConnMgr.LowWater 0
ipfs config --json Swarm.ConnMgr.HighWater 0

[[ ! $isLAN ]] && ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["http://'$myIP':8080", "http://127.0.0.1:8080", "http://127.0.1.1:8080" ]' \
                         ||   ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["http://127.0.0.1:8080", "http://127.0.1.1:8080" ]'

ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "GET", "POST"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Credentials '["true"]'

## For ipfs.js = https://github.com/ipfs/js-ipfs/blob/master/docs/DELEGATE_ROUTERS.md
ipfs config --json Addresses.Swarm | jq '. += ["/ip4/0.0.0.0/tcp/30215/ws"]' > /tmp/30215.ws
ipfs config --json Addresses.Swarm "$(cat /tmp/30215.ws)"


ipfs config Addresses.API "/ip4/0.0.0.0/tcp/5001"
ipfs config Addresses.Gateway "/ip4/0.0.0.0/tcp/8080"

######### CLEAN DEFAULT BOOTSTRAP ADD Astroport.ONE Officials ###########
ipfs bootstrap rm --all

for bootnode in $(cat ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | grep -Ev "#") # remove comments
    do
        ipfsnodeid=${bootnode##*/}
        ipfs bootstrap add $bootnode
    done

sudo systemctl restart ipfs

## Add ulimit "open files" (avoid ipfs hang)
ulimit -n 2048

} # this ensures the entire script is downloaded #
# IPFS CONFIG documentation: https://github.com/ipfs/go-ipfs/blob/master/docs/config.md#addressesswarm
