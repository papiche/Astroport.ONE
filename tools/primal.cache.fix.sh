#!/bin/bash 

is_valid_g1pub() {
    [[ "$1" =~ ^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]{43,44}$ ]]
}

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

