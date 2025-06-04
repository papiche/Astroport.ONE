#!/bin/bash

# Diagon Alley stall management script
# Usage: ./diagonalley.sh <command> [args]
##################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Function to get UMAP directory
get_umap_dir() {
    local LAT=$1
    local LON=$2
    
    # Validate coordinates
    local ZLAT=$(makecoord ${LAT})
    local ZLON=$(makecoord ${LON})
    [[ "$ZLAT" != "$LAT" || "$LAT" == "" ]] && echo "# ERROR - $LAT bad format -" && exit 1
    [[ "$ZLON" != "$LON" || "$LON" == "" ]] && echo "# ERROR - $LON bad format -" && exit 1

    # Compute UMAP, USECTOR, UREGION
    local SLAT="${LAT::-1}"
    local SLON="${LON::-1}"
    local SECTOR="_${SLAT}_${SLON}"
    local RLAT="$(echo ${LAT} | cut -d '.' -f 1)"
    local RLON="$(echo ${LON} | cut -d '.' -f 1)"
    local REGION="_${RLAT}_${RLON}"

    # Create UMAP directory path
    local UMAP_DIR="$HOME/.zen/tmp/${IPFSNODEID}/UPLANET/__/${REGION}/${SECTOR}/_${LAT}_${LON}"
    mkdir -p "$UMAP_DIR"
}

# List all stalls and their products
get_stalls() {
    local UMAP_DIR="$1"
    local STALLS_DIR="$UMAP_DIR/stalls"
    if [ -d "$STALLS_DIR" ]; then
        echo "{\"umap_dir\": \"$UMAP_DIR\", \"stalls\": ["
        local first=true
        for STALL_DIR in "$STALLS_DIR"/*/; do
            if [ -d "$STALL_DIR" ]; then
                local STALL_ID=$(basename "$STALL_DIR")
                if [ "$first" = true ]; then
                    first=false
                else
                    echo ","
                fi
                echo "  {"
                echo "    \"stall_id\": \"$STALL_ID\","
                if [ -f "$STALL_DIR/public/indexer_id" ]; then
                    echo "    \"indexer_id\": \"$(cat "$STALL_DIR/public/indexer_id")\","
                fi
                if [ -f "$STALL_DIR/public/url" ]; then
                    echo "    \"url\": \"$(cat "$STALL_DIR/public/url")\","
                fi
                if [ -f "$STALL_DIR/public/lat" ]; then
                    echo "    \"lat\": \"$(cat "$STALL_DIR/public/lat")\","
                fi
                if [ -f "$STALL_DIR/public/lon" ]; then
                    echo "    \"lon\": \"$(cat "$STALL_DIR/public/lon")\","
                fi
                if [ -f "$STALL_DIR/public/products.json" ]; then
                    echo "    \"products\": $(cat "$STALL_DIR/public/products.json")"
                else
                    echo "    \"products\": []"
                fi
                echo "  }"
            fi
        done
        echo "]}"
    else
        echo "{\"umap_dir\": \"$UMAP_DIR\", \"stalls\": []}"
    fi
}

# Main script logic
case "$1" in
    "register")
        # Register a new stall
        # Usage: ./diagonalley.sh register <stall_id> <stall_url> <lat> <lon>
        STALL_ID="$2"
        STALL_URL="$3"
        LAT="$4"
        LON="$5"
        
        # Get UMAP directory
        UMAP_DIR=$(get_umap_dir "$LAT" "$LON")
        STALL_DIR="$UMAP_DIR/stalls/$STALL_ID"
        mkdir -p "$STALL_DIR"
        
        # Create public and private directories
        mkdir -p "$STALL_DIR/public"
        mkdir -p "$STALL_DIR/.private"
        
        # Save public stall information
        echo "$STALL_URL" > "$STALL_DIR/public/url"
        echo "$LAT" > "$STALL_DIR/public/lat"
        echo "$LON" > "$STALL_DIR/public/lon"
        
        # Generate indexer ID
        INDEXER_ID="indexer_$(openssl rand -hex 8)"
        echo "$INDEXER_ID" > "$STALL_DIR/public/indexer_id"
        
        # Generate keypair for stall (private files)
        openssl genrsa -out "$STALL_DIR/.private/private.pem" 2048
        openssl rsa -in "$STALL_DIR/.private/private.pem" -pubout -out "$STALL_DIR/public/public.pem"
        
        # Create public products.json
        echo "[]" > "$STALL_DIR/public/products.json"
        
        # Create .gitignore to prevent publishing private files
        echo ".private/*" > "$STALL_DIR/.gitignore"
        
        # Return stall information
        echo "{\"stall_id\": \"$STALL_ID\", \"indexer_id\": \"$INDEXER_ID\", \"shopstatus\": true, \"rating\": 100, \"lat\": \"$LAT\", \"lon\": \"$LON\"}"
        ;;
        
    "products")
        # Get products for a stall
        # Usage: ./diagonalley.sh products <stall_id> <indexer_id> <lat> <lon>
        STALL_ID="$2"
        INDEXER_ID="$3"
        LAT="$4"
        LON="$5"
        
        # Get UMAP directory
        UMAP_DIR=$(get_umap_dir "$LAT" "$LON")
        STALL_DIR="$UMAP_DIR/stalls/$STALL_ID"
        
        if [ ! -d "$STALL_DIR" ]; then
            echo "{\"error\": \"Stall not found\"}"
            exit 1
        fi
        
        # Check indexer ID
        if [ "$(cat "$STALL_DIR/public/indexer_id")" != "$INDEXER_ID" ]; then
            echo "{\"error\": \"Invalid indexer ID\"}"
            exit 1
        fi
        
        # Return products list
        if [ -f "$STALL_DIR/public/products.json" ]; then
            cat "$STALL_DIR/public/products.json"
        else
            echo "[]"
        fi
        ;;
        
    "order")
        # Place an order
        # Usage: ./diagonalley.sh order <stall_id> <order_data> <lat> <lon>
        STALL_ID="$2"
        ORDER_DATA="$3"
        LAT="$4"
        LON="$5"
        
        # Get UMAP directory
        UMAP_DIR=$(get_umap_dir "$LAT" "$LON")
        STALL_DIR="$UMAP_DIR/stalls/$STALL_ID"
        
        if [ ! -d "$STALL_DIR" ]; then
            echo "{\"error\": \"Stall not found\"}"
            exit 1
        fi
        
        # Create orders directory (private)
        mkdir -p "$STALL_DIR/.private/orders"
        
        # Generate checking ID
        CHECKING_ID="order_$(openssl rand -hex 8)"
        
        # Save order (private)
        echo "$ORDER_DATA" > "$STALL_DIR/.private/orders/$CHECKING_ID.json"
        
        # Create metadata with signature
        DESCRIPTION="Order $CHECKING_ID for stall $STALL_ID"
        SIGNATURE=$(echo "$DESCRIPTION" | openssl dgst -sha256 -sign "$STALL_DIR/.private/private.pem" | base64 -w 0)
        
        METADATA="[[\"text/plain\",\"$DESCRIPTION\"],[\"application/vnd.diagonalley.signature\",\"$SIGNATURE\"]]"
        
        # Return order information
        echo "{\"metadata\": \"$METADATA\", \"checking_id\": \"$CHECKING_ID\"}"
        ;;
        
    "status")
        # Check order status
        # Usage: ./diagonalley.sh status <checking_id> <lat> <lon>
        CHECKING_ID="$2"
        LAT="$3"
        LON="$4"
        
        # Get UMAP directory
        UMAP_DIR=$(get_umap_dir "$LAT" "$LON")
        
        # Find order in stalls
        for STALL_DIR in "$UMAP_DIR/stalls"/*/; do
            if [ -f "$STALL_DIR/.private/orders/$CHECKING_ID.json" ]; then
                STATUS=$(jq -r '.status' "$STALL_DIR/.private/orders/$CHECKING_ID.json")
                echo "{\"status\": \"$STATUS\"}"
                exit 0
            fi
        done
        
        echo "{\"status\": \"UNKNOWN\"}"
        ;;
        
    "get_stalls")
        # Get stalls for coordinates
        # Usage: ./diagonalley.sh get_stalls <lat> <lon>
        LAT="$2"
        LON="$3"
        
        # Get UMAP directory
        UMAP_DIR=$(get_umap_dir "$LAT" "$LON")
        
        # Get stalls information
        STALLS_INFO=$(get_stalls "$UMAP_DIR")
        echo "$STALLS_INFO"
        ;;
        
    *)
        echo "Usage: ./diagonalley.sh <command> [args]"
        echo "Commands:"
        echo "  register <stall_id> <stall_url> <lat> <lon>"
        echo "  products <stall_id> <indexer_id> <lat> <lon>"
        echo "  order <stall_id> <order_data> <lat> <lon>"
        echo "  status <checking_id> <lat> <lon>"
        echo "  get_stalls <lat> <lon>"
        echo ""
        echo "Description:"
        echo "  register  : Register a new stall with given coordinates"
        echo "  products  : Get products list for a specific stall"
        echo "  order     : Place an order for a stall"
        echo "  status    : Check status of an order"
        echo "  get_stalls : List all stalls and their products for given coordinates"
        exit 1
        ;;
esac 