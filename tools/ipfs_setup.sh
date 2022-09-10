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

# CHECK if daemon is already running
if [[ $(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1) ]]; then
    ipfs id && echo "ipfs swarm peers: " && ipfs swarm peers
    echo "ipfs bootstrap list: " && ipfs bootstrap list
    echo "ipfs daemon already running...!"
    exit 0
fi

echo -e "Astroport activate IPFS Layer installation..."

# CHECK node IP isLAN?
myIP=$(hostname -I | awk '{print $1}')
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")

MACHINE_TYPE=`uname -m`

# INIT ipfs
[[ $isLAN ]] && ipfs init -p lowpower \
|| ipfs init -p server

## Special Xbian init.d config
if [[ "$USER" == "xbian" ]]; then
    sudo cp ~/.zen/astrXbian/.install/templates/ipfs/ipfs-initV.sh /etc/init.d/ipfs
    sudo chmod 755 /etc/init.d/ipfs
    sudo touch /var/log/ipfs.log && sudo chown xbian /var/log/ipfs.log
else
    ## DEBIAN
    echo "CREATE SYSTEMD ipfs SERVICE >>>>>>>>>>>>>>>>>>"
cat > /tmp/ipfs.service <<EOF
[Unit]
Description=IPFS daemon
After=network.target

[Service]
User=_USER_
ExecStart=/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesys-pubsub --enable-gc
Restart=on-failure
CPUAccounting=true
CPUQuota=60%

[Install]
WantedBy=multi-user.target
EOF

    sudo cp -f /tmp/ipfs.service /etc/systemd/system/
    sudo sed -i "s/_USER_/$USER/g" /etc/systemd/system/ipfs.service

    [[ -d ~/.ipfs ]] && sudo chown -R $USER:$USER ~/.ipfs
    sudo systemctl daemon-reload
    sudo systemctl enable ipfs
fi


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
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["http://127.0.0.1:8080", "http://astroport", "https://astroport.com", "https://qo-op.com", "https://tube.copylaradio.com" ]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "GET", "POST"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Credentials '["true"]'

ipfs config Addresses.API "/ip4/0.0.0.0/tcp/5001"
ipfs config Addresses.Gateway "/ip4/0.0.0.0/tcp/8080"

######### CLEAN DEFAULT BOOTSTRAP TO STAY INVISIBLE ###########
ipfs bootstrap rm --all
###########################################
# BOOTSTRAP NODES ARE ADDED LATER
###########################################
# AVOID CONFLICT WITH KODI ./.install/.kodi/userdata/guisettings.xml
ipfs config Addresses.Gateway "/ip4/0.0.0.0/tcp/8080"

[[ "$USER" != "xbian" ]] && sudo systemctl restart ipfs

} # this ensures the entire script is downloaded #
# IPFS CONFIG documentation: https://github.com/ipfs/go-ipfs/blob/master/docs/config.md#addressesswarm
