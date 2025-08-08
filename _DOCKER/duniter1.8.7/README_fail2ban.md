# Fail2ban Configuration for Duniter Docker Container

This directory contains a complete fail2ban configuration to protect your Duniter Docker container from abuse and DDoS attacks.

## Configuration Overview

The configuration is designed to:
- **Ban IPs** that make more than **2 requests per 15 minutes**
- **Ban duration**: 24 hours (86400 seconds)
- **Monitor all Duniter ports**: 10901 (BMA), 20901 (WS2P), 30901 (GVA), 9220 (Debug)
- **Whitelist G1 blockchain peers** to prevent legitimate peers from being banned
- **Detect DDOS attacks** based on actual Duniter logs
- **Ignore Docker internal networks** (172.20.0.0/16, 172.17.0.0/16)

## Files Description

### `fail2ban.conf`
Main fail2ban configuration file that defines:
- Default ban settings (24 hours ban, 15 minutes window, 2 max retries)
- Individual jails for each Duniter service port
- Log path configuration for Docker containers

### `duniter.conf`
Custom filter configuration that:
- Detects DDOS attacks based on actual Duniter logs (`ddos: denied: entry:`)
- Detects failed HTTP requests (4xx and 5xx status codes)
- Ignores successful requests (2xx status codes)
- Ignores health checks and common monitoring endpoints
- Ignores legitimate WS2P peer connections and blockchain operations

### `install_fail2ban.sh`
Automated installation script that:
- Installs fail2ban if not present
- Copies configuration files to proper locations
- Creates custom iptables actions for Docker
- Updates G1 peers whitelist from the official API
- Restarts and enables the fail2ban service

### `g1_peers_whitelist.conf`
Static whitelist of G1 blockchain peers that should never be banned.

### `update_g1_peers.sh`
Script to automatically update the G1 peers whitelist by fetching current peers from the official G1 network API.

## Installation

1. **Run the installation script as root:**
   ```bash
   sudo ./install_fail2ban.sh
   ```

2. **Verify installation:**
   ```bash
   sudo fail2ban-client status
   ```

## Configuration Details

### Ban Rules
- **Max retries**: 2 requests
- **Time window**: 15 minutes (900 seconds)
- **Ban duration**: 24 hours (86400 seconds)
- **Action**: Block all ports using iptables

### Monitored Services
- **BMA API** (port 10901): REST API for blockchain data
- **WS2P** (port 20901): WebSocket protocol for peer-to-peer communication
- **GVA** (port 30901): GraphQL API for advanced queries
- **Debug** (port 9220): Debug interface (if enabled)

### Whitelisted Networks
- **G1 Blockchain Peers**: All legitimate peers from the G1 network
- **Docker Internal Networks**: 172.20.0.0/16, 172.17.0.0/16, 10.0.0.0/8, 192.168.0.0/16
- **Localhost**: 127.0.0.1/8, ::1

### Log Monitoring
The configuration monitors Docker container logs at:
```
/var/lib/docker/containers/*/logs/*.log
```

## Management Commands

### Check Status
```bash
# Overall status
sudo fail2ban-client status

# Specific jail status
sudo fail2ban-client status duniter-bma
sudo fail2ban-client status duniter-ws2p
sudo fail2ban-client status duniter-gva
sudo fail2ban-client status duniter-debug
```

### View Logs
```bash
# Fail2ban logs
sudo tail -f /var/log/fail2ban.log

# Docker container logs
sudo docker logs <container_name>
```

### Ban Management
```bash
# Unban a specific IP
sudo fail2ban-client set duniter-bma unbanip <IP_ADDRESS>

# Unban all IPs in a jail
sudo fail2ban-client set duniter-bma unbanip --all

# Check banned IPs
sudo fail2ban-client get duniter-bma banned
```

### Service Management
```bash
# Restart fail2ban
sudo systemctl restart fail2ban

# Stop fail2ban
sudo systemctl stop fail2ban

# Start fail2ban
sudo systemctl start fail2ban

# Check service status
sudo systemctl status fail2ban
```

## Customization

### Adjust Ban Duration
Edit `fail2ban.conf` and modify the `bantime` value:
```ini
bantime = 86400  # 24 hours in seconds
```

### Adjust Request Limits
Edit `fail2ban.conf` and modify the `maxretry` and `findtime` values:
```ini
maxretry = 2      # Number of requests
findtime = 900    # Time window in seconds (15 minutes)
```

### Add Custom Filters
Edit `duniter.conf` to add custom regex patterns for specific attack patterns.

### Update G1 Peers Whitelist
```bash
# Update whitelist from official G1 API
./update_g1_peers.sh

# Restart fail2ban to apply changes
sudo systemctl restart fail2ban
```

## Troubleshooting

### Check if fail2ban is working
```bash
# Test the filter
sudo fail2ban-regex /var/lib/docker/containers/*/logs/*.log /etc/fail2ban/filter.d/duniter.conf
```

### Check iptables rules
```bash
# List fail2ban chains
sudo iptables -L | grep fail2ban

# Check specific jail rules
sudo iptables -L fail2ban-duniter-bma -n
```

### Common Issues

1. **No logs being processed**: Ensure Docker logging driver is set to `json-file`
2. **IPs not being banned**: Check if iptables rules are being created properly
3. **False positives**: Adjust the `ignoreregex` patterns in `duniter.conf`

## Security Notes

- This configuration only bans based on HTTP error responses
- Consider additional security measures like rate limiting at the reverse proxy level
- Monitor fail2ban logs regularly for unusual patterns
- Keep fail2ban updated to the latest version

## Support

For issues or questions:
1. Check the fail2ban logs: `/var/log/fail2ban.log`
2. Verify Docker container logs are accessible
3. Test the filter configuration with `fail2ban-regex`
4. Ensure iptables is properly configured on your system 