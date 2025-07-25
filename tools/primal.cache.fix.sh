#!/bin/bash 

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
        echo "Invalid primal in $f ($key) - trying to fix with silkaj..."
        
        # Try to recover the primal using silkaj with better error handling
        silkaj_output=$(silkaj --json money primal "$g1pub" 2>&1)
        
        # Check if silkaj command was successful and returned valid JSON
        if echo "$silkaj_output" | jq . >/dev/null 2>&1; then
            primal=$(echo "$silkaj_output" | jq -r .primal_source_pubkey 2>/dev/null)
            if is_valid_g1pub "$primal"; then
                echo "Fixed: $g1pub.primal -> $primal"
                echo "$primal" > "$f"
            else
                echo "Could not fix $f - invalid primal returned: $primal"
            fi
        else
            echo "Could not fix $f - silkaj error or invalid JSON:"
            echo "$silkaj_output" | head -3
        fi
    fi
done

# Clean G1PRIME files in player directories
echo "Cleaning G1PRIME files in player directories..."
for player_dir in ~/.zen/game/nostr/*/; do
    [[ ! -d "$player_dir" ]] && continue
    
    g1prime_file="$player_dir/G1PRIME"
    [[ ! -f "$g1prime_file" ]] && continue

    g1pub=$(cat $player_dir/G1PUBNOSTR)
    
    content=$(cat "$g1prime_file")
    
    # Look for a valid G1PUB pattern in the content
    if ! is_valid_g1pub "$content"; then
        echo "Invalid G1PRIME in $player_dir ($content) - trying to fix with silkaj..."
        # Try to recover the primal using silkaj with better error handling
        silkaj_output=$(silkaj --json money primal "$g1pub" 2>&1)
        
        # Check if silkaj command was successful and returned valid JSON
        if echo "$silkaj_output" | jq . >/dev/null 2>&1; then
            primal=$(echo "$silkaj_output" | jq -r .primal_source_pubkey 2>/dev/null)
            if is_valid_g1pub "$primal"; then
                echo "Fixed: $g1pub.primal -> $primal"
                echo "$primal" > "$f"
            else
                echo "Could not fix $f - invalid primal returned: $primal"
            fi
        else
            echo "Could not fix $f - silkaj error or invalid JSON:"
            echo "$silkaj_output" | head -3
        fi
    fi
done

echo "Primal cache and G1PRIME files cleanup completed."