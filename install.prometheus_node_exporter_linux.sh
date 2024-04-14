#!/bin/bash
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1
## INSTALL NODE MONITORING TOOLS
#~ prometheus & grafana

mkdir -p ~/.zen/tmp
cd  ~/.zen/tmp

# Check processor architecture
architecture=$(uname -m)

##############################################################
## "GRAFANA" NODE + PROMETHEUS GATEWAY (CONSUME DISK SPACE !)
##############################################################
if [[ "$1" == "GRAFANA" && ! -d ~/.zen/prometheus ]]; then
    # Grafana
    sudo apt-get install -y adduser libfontconfig1 musl

    [ "$architecture" == "x86_64" ] \
    && wget https://dl.grafana.com/oss/release/grafana_10.4.2_amd64.deb \
    && sudo dpkg -i grafana_10.4.2_amd64.deb

    [ "$architecture" == "aarch64" ] \
    && wget https://dl.grafana.com/oss/release/grafana_10.4.2_arm64.deb \
    && sudo dpkg -i grafana_10.4.2_arm64.deb


### NOT starting on installation, please execute the following statements to configure grafana to start automatically using systemd
 sudo systemctl daemon-reload
 sudo systemctl enable grafana-server
### You can start grafana-server by executing
 sudo systemctl start grafana-server


    ## PROMETHEUS GATEWAY
    [ "$architecture" == "x86_64" ] \
        && wget -O prometheus.tar.gz https://github.com/prometheus/prometheus/releases/download/v2.45.4/prometheus-2.45.4.linux-amd64.tar.gz
    [ "$architecture" == "aarch64" ] \
        && wget -O prometheus.tar.gz https://github.com/prometheus/prometheus/releases/download/v2.45.4/prometheus-2.45.4.linux-arm64.tar.gz

    tar -xvzf prometheus.tar.gz
    mv $(ls -d prometheus-*) ~/.zen/prometheus

    ## prometheus.

fi



######################################################
## PROMETHEUS node_exporter
######################################################
# Download appropriate version of node_exporter
if [ "$architecture" == "x86_64" ]; then
    wget --no-check-certificate -O node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    # /ipfs/QmRDwRWPpfK1XmXQew8HgoqJgC9X5WXR2Qr82sg4MqJ4M7
elif [ "$architecture" == "aarch64" ]; then
    wget --no-check-certificate -O node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-arm64.tar.gz
    # /ipfs/QmQ8YukwTjUrTbibAWq8sR4c29ye33GX8v4T4GW1C1vDCk
elif [ "$architecture" == "armv7l" ]; then
    wget --no-check-certificate -O node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-armv7.tar.gz
elif [ "$architecture" == "armv6l" ]; then
    wget --no-check-certificate -O node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-armv6.tar.gz
else
    echo "Error: Unknown architecture"
    exit 1
fi

tar -xvzf node_exporter.tar.gz

cd $(ls -d node_exporter-*)

# Install
sudo cp node_exporter /usr/local/bin/
cd ..

# Test
[[ ! $(ls /usr/local/bin/node_exporter) ]] \
&& echo "node_exporter NOT installed" && exit 1 \
|| echo "node_exporter installed"




exit 0
