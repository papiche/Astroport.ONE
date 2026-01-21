#!/bin/bash 
################################################################################
# primal.cache.fix.sh
# Clean and fix invalid primal cache files using G1primal.sh wrapper
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

is_valid_g1pub() {
    [[ "$1" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,44}$ ]]
}

# Clean cache files in ~/.zen/tmp/coucou/
echo "Cleaning primal cache files..."
for f in ~/.zen/tmp/coucou/*.primal; do
    [[ ! -f "$f" ]] && continue
    key=$(cat "$f" | head -n 1)
    if ! is_valid_g1pub "$key"; then
        # Get the G1 pubkey from the filename (remove .primal extension)
        g1pub=$(basename "$f" .primal)
        echo "Invalid primal in $f ($key) - trying to fix via G1primal.sh..."
        
        # Remove the invalid cache file so G1primal.sh will fetch fresh data
        rm -f "$f"
        
        # Use G1primal.sh wrapper which handles caching, retries, and BMAS rotation
        primal=$(${MY_PATH}/G1primal.sh "$g1pub" 2>/dev/null)
        
        if is_valid_g1pub "$primal"; then
            echo "Fixed: $g1pub.primal -> $primal"
        else
            echo "Could not fix $f - G1primal.sh returned: $primal"
        fi
    fi
done

# Clean G1PRIME files in player directories
echo "Cleaning G1PRIME files in player directories..."
for player_dir in ~/.zen/game/nostr/*/; do
    [[ ! -d "$player_dir" ]] && continue
    
    g1prime_file="$player_dir/G1PRIME"
    [[ ! -f "$g1prime_file" ]] && continue

    g1pub=$(cat $player_dir/G1PUBNOSTR 2>/dev/null)
    [[ -z "$g1pub" ]] && continue
    
    content=$(cat "$g1prime_file")
    
    # Look for a valid G1PUB pattern in the content
    if ! is_valid_g1pub "$content"; then
        echo "Invalid G1PRIME in $player_dir ($content) - trying to fix via G1primal.sh..."
        
        # Use G1primal.sh wrapper which handles caching, retries, and BMAS rotation
        primal=$(${MY_PATH}/G1primal.sh "$g1pub" 2>/dev/null)
        
        if is_valid_g1pub "$primal"; then
            echo "Fixed: $g1pub G1PRIME -> $primal"
            echo "$primal" > "$g1prime_file"
        else
            echo "Could not fix $g1prime_file - G1primal.sh returned: $primal"
        fi
    fi
done

echo "Primal cache and G1PRIME files cleanup completed."