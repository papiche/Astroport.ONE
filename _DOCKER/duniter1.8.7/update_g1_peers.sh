#!/bin/bash

# Script to update G1 peers whitelist for fail2ban
# Fetches current peers from https://g1.duniter.org/network/peers

set -e

echo "=== Updating G1 Peers Whitelist ==="

# Create temporary file
TEMP_FILE=$(mktemp)
WHITELIST_FILE="g1_peers_whitelist.conf"

# Fetch peers from G1 network API
echo "Fetching current G1 peers from https://g1.duniter.org/network/peers..."

# Download peers data
PEERS_JSON=$(curl -s "https://g1.duniter.org/network/peers" || echo '{"peers": []}')

# Extract IPs and domains from endpoints
echo "# G1 Blockchain Peers Whitelist for Fail2ban" > "$TEMP_FILE"
echo "# Auto-generated on $(date)" >> "$TEMP_FILE"
echo "# Source: https://g1.duniter.org/network/peers" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"

# Extract IPs and domains from the JSON response
echo "$PEERS_JSON" | jq -r '.peers[].endpoints[]' 2>/dev/null | while read -r endpoint; do
    if [[ $endpoint =~ ^[A-Z_]+[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9]+) ]]; then
        # Extract hostname/IP from endpoint
        host="${BASH_REMATCH[1]}"
        
        # Skip if it's already an IP
        if [[ $host =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$host" >> "$TEMP_FILE"
        else
            # Try to resolve domain to IP
            resolved_ip=$(dig +short "$host" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
            if [[ -n "$resolved_ip" ]]; then
                echo "$resolved_ip" >> "$TEMP_FILE"
            fi
            # Also add the domain name
            echo "$host" >> "$TEMP_FILE"
        fi
    fi
done

# Add standard network ranges
echo "" >> "$TEMP_FILE"
echo "# Docker internal networks (for local peer connections)" >> "$TEMP_FILE"
echo "172.20.0.0/16" >> "$TEMP_FILE"
echo "172.17.0.0/16" >> "$TEMP_FILE"
echo "10.0.0.0/8" >> "$TEMP_FILE"
echo "192.168.0.0/16" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"

# Add localhost
echo "# Localhost and loopback" >> "$TEMP_FILE"
echo "127.0.0.1" >> "$TEMP_FILE"
echo "::1" >> "$TEMP_FILE"

# Remove duplicates and sort
sort -u "$TEMP_FILE" > "$WHITELIST_FILE"

# Clean up
rm "$TEMP_FILE"

echo "Whitelist updated: $WHITELIST_FILE"
echo "Total unique entries: $(wc -l < "$WHITELIST_FILE")"

# Show some examples
echo ""
echo "Sample entries:"
head -20 "$WHITELIST_FILE"

echo ""
echo "=== Update Complete ==="
echo "Don't forget to restart fail2ban after updating the whitelist:"
echo "sudo systemctl restart fail2ban" 