# WireGuard LAN System - Documentation

## Overview

This system provides an easy way to set up a WireGuard VPN LAN using existing SSH keys. It automatically converts SSH keys to WireGuard format and manages both server and client configurations.

## Files

- **`wg-deploy.sh`** - Main deployment script (recommended entry point)
- **`wireguard_control.sh`** - Server management script
- **`wg-client-setup.sh`** - Client configuration script

## Quick Start

### 1. Server Setup

```bash
# On the server machine
cd Astroport.ONE/tools
./wg-deploy.sh

# Choose option 1: "Configurer ce serveur WireGuard"
# Follow the WireGuard Control menu to initialize the server
```

### 2. Client Setup

```bash
# On each client machine
cd Astroport.ONE/tools
./wg-deploy.sh

# Choose option 2: "Configurer ce client WireGuard"
# Enter server details when prompted
```

## Detailed Usage

### Server Management (`wireguard_control.sh`)

**Initialize Server:**
```bash
./wireguard_control.sh
# Choose option 1 to set up the server
```

**Add Client:**
```bash
./wireguard_control.sh
# Choose option 2 and provide client SSH public key
```

**Features:**
- Automatic SSH key conversion
- IP address allocation (10.99.99.2-254)
- Client management (add/remove)
- Service status monitoring

### Client Setup (`wg-client-setup.sh`)

**Interactive Mode:**
```bash
./wg-client-setup.sh
# Follow prompts to configure client
```

**Automatic Mode:**
```bash
./wg-client-setup.sh auto <server_ip> <port> <server_pubkey> <client_ip>
```

**Example:**
```bash
./wg-client-setup.sh auto 192.168.1.100 51820 "server_public_key_here" 10.99.99.2
```

## Network Configuration

- **VPN Network:** 10.99.99.0/24
- **Server IP:** 10.99.99.1
- **Client IPs:** 10.99.99.2 - 10.99.99.254
- **Port:** 51820 (UDP)

## Key Conversion

The system automatically converts SSH Ed25519 keys to WireGuard format:

1. **Private Key:** Last 32 bytes of SSH private key
2. **Public Key:** Last 32 bytes of SSH public key

This ensures compatibility between server and client configurations.

## Troubleshooting

### Common Issues

1. **Permission Denied:**
   ```bash
   sudo chmod +x *.sh
   ```

2. **WireGuard Not Found:**
   ```bash
   # Ubuntu/Debian
   sudo apt install wireguard
   
   # CentOS/RHEL
   sudo yum install wireguard-tools
   ```

3. **Service Won't Start:**
   ```bash
   sudo systemctl status wg-quick@wg0
   sudo journalctl -u wg-quick@wg0
   ```

4. **Connection Issues:**
   ```bash
   # Check server status
   sudo wg show wg0
   
   # Test connectivity
   ping 10.99.99.1
   ```

### Debug Mode

Enable verbose logging:
```bash
sudo wg-quick up wg0 --verbose
```

## Security Features

- **Key-based authentication** using SSH keys
- **Restricted network access** (LAN only by default)
- **Automatic firewall rules** for VPN traffic
- **Secure key storage** with proper permissions

## Advanced Configuration

### Custom Network Range

Edit the scripts to change the network:
```bash
# In wireguard_control.sh and wg-client-setup.sh
local NETWORK="10.99.99.0/24"  # Change this line
```

### Additional Firewall Rules

Add custom iptables rules in the server configuration:
```bash
# In wireguard_control.sh setup_server function
PostUp = iptables -A FORWARD -i %i -j ACCEPT; \
         iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; \
         iptables -A FORWARD -p tcp --dport 80 -j ACCEPT
```

## Backup and Recovery

### Backup Configuration

```bash
sudo cp /etc/wireguard/wg0.conf ~/wg0.conf.backup
```

### Restore Configuration

```bash
sudo cp ~/wg0.conf.conf.backup /etc/wireguard/wg0.conf
sudo systemctl restart wg-quick@wg0
```

## Monitoring

### Check Service Status

```bash
sudo systemctl status wg-quick@wg0
sudo wg show wg0
```

### View Logs

```bash
sudo journalctl -u wg-quick@wg0 -f
```

## Performance

- **Low latency** - WireGuard is designed for performance
- **Minimal overhead** - Efficient cryptographic operations
- **Fast handshakes** - Quick connection establishment

## Compatibility

- **Linux:** All major distributions
- **SSH Keys:** Ed25519 format (recommended)
- **Network:** IPv4 support
- **Architecture:** x86_64, ARM64, etc.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Verify all dependencies are installed
3. Check system logs for errors
4. Ensure proper network configuration

## License

This system is part of the Astroport.ONE project and follows the same licensing terms.
