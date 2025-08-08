#!/bin/bash

# Fail2ban installation script for Duniter Docker container
# This script installs and configures fail2ban to protect Duniter services

set -e

echo "=== Fail2ban Installation for Duniter Docker Container ==="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Install fail2ban if not already installed
if ! command -v fail2ban-server &> /dev/null; then
    echo "Installing fail2ban..."
    apt-get update
    apt-get install -y fail2ban
else
    echo "Fail2ban is already installed"
fi

# Create fail2ban configuration directory if it doesn't exist
mkdir -p /etc/fail2ban/jail.d

# Copy the custom configuration files
echo "Copying fail2ban configuration files..."

# Copy the main configuration
cp fail2ban.conf /etc/fail2ban/jail.d/duniter.conf

# Copy the filter configuration
cp duniter.conf /etc/fail2ban/filter.d/duniter.conf

# Copy the G1 peers whitelist
cp g1_peers_whitelist.conf /etc/fail2ban/g1_peers_whitelist.conf

# Set proper permissions
chmod 644 /etc/fail2ban/jail.d/duniter.conf
chmod 644 /etc/fail2ban/filter.d/duniter.conf
chmod 644 /etc/fail2ban/g1_peers_whitelist.conf

# Create a custom action for Docker containers
cat > /etc/fail2ban/action.d/iptables-docker.conf << 'EOF'
[Definition]
actionstart = iptables -N fail2ban-<name>
              iptables -A fail2ban-<name> -j RETURN
              iptables -I INPUT -p tcp -m multiport --dports <port> -j fail2ban-<name>

actionstop = iptables -D INPUT -p tcp -m multiport --dports <port> -j fail2ban-<name>
             iptables -F fail2ban-<name>
             iptables -X fail2ban-<name>

actioncheck = iptables -n -L INPUT | grep -q 'fail2ban-<name>[ \t]'

actionban = iptables -I fail2ban-<name> 1 -s <ip> -j DROP

actionunban = iptables -D fail2ban-<name> -s <ip> -j DROP

[Init]
name = default
port = ssh
protocol = tcp
EOF

# Update G1 peers whitelist
echo "Updating G1 peers whitelist..."
if command -v jq &> /dev/null && command -v dig &> /dev/null; then
    ./update_g1_peers.sh
    cp g1_peers_whitelist.conf /etc/fail2ban/g1_peers_whitelist.conf
else
    echo "Warning: jq or dig not found. Using static whitelist."
fi

# Restart fail2ban service
echo "Restarting fail2ban service..."
systemctl restart fail2ban

# Enable fail2ban to start on boot
systemctl enable fail2ban

# Check fail2ban status
echo "Checking fail2ban status..."
systemctl status fail2ban --no-pager -l

# Show configured jails
echo "Configured jails:"
fail2ban-client status

echo ""
echo "=== Installation Complete ==="
echo "Fail2ban is now configured to protect your Duniter Docker container."
echo ""
echo "Configuration details:"
echo "- Bans IPs making more than 2 requests per 15 minutes"
echo "- Ban duration: 24 hours"
echo "- Monitored ports: 10901 (BMA), 20901 (WS2P), 30901 (GVA), 9220 (Debug)"
echo "- G1 blockchain peers are whitelisted and will never be banned"
echo "- Docker internal networks (172.20.0.0/16, 172.17.0.0/16) are whitelisted"
echo ""
echo "Useful commands:"
echo "- Check status: fail2ban-client status"
echo "- Check specific jail: fail2ban-client status duniter-bma"
echo "- Unban IP: fail2ban-client set duniter-bma unbanip <IP_ADDRESS>"
echo "- View logs: tail -f /var/log/fail2ban.log" 