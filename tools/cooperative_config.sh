#!/bin/bash
################################################################################
# cooperative_config.sh - Cooperative Configuration Manager via DID NOSTR
#
# Stores cooperative configuration in the UPLANETNAME_G1 DID (kind 30800)
# All sensitive values are symmetrically encrypted with $UPLANETNAME
#
# This allows all IPFS swarm machines to share the same configuration
# without storing secrets in local .env files.
#
# Usage:
#   source cooperative_config.sh
#   
#   # Get a config value (automatically decrypts)
#   OC_TOKEN=$(coop_config_get "OPENCOLLECTIVE_PERSONAL_TOKEN")
#   
#   # Set a config value (automatically encrypts)
#   coop_config_set "OPENCOLLECTIVE_PERSONAL_TOKEN" "my_secret_token"
#   
#   # List all config keys
#   coop_config_list
#
# Storage: DID NOSTR kind 30800 with d-tag "cooperative-config"
# Encryption: AES-256-CBC with $UPLANETNAME as key (base64 encoded)
################################################################################

MY_PATH="$(dirname "${BASH_SOURCE[0]}")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Source environment if not already done
[[ -z "$UPLANETNAME" ]] && source "${MY_PATH}/my.sh" 2>/dev/null

# Configuration
COOP_CONFIG_KIND=30800
COOP_CONFIG_D_TAG="cooperative-config"
COOP_CONFIG_KEYFILE="${HOME}/.zen/game/uplanet.G1.nostr"
COOP_CONFIG_CACHE="${HOME}/.zen/tmp/cooperative_config.cache.json"
COOP_CONFIG_RELAY="${myRELAY:-wss://relay.copylaradio.com}"
COOP_CONFIG_LOCAL_RELAY="${myLocalRELAY:-ws://127.0.0.1:7777}"

# Encryption method: AES-256-CBC with UPLANETNAME as key
# Key derivation: sha256 of UPLANETNAME (32 bytes)

################################################################################
# Encryption/Decryption Functions
################################################################################

# Encrypt a value with UPLANETNAME
# Usage: coop_encrypt "plaintext"
# Returns: base64 encoded encrypted value
coop_encrypt() {
    local plaintext="$1"
    
    if [[ -z "$UPLANETNAME" ]]; then
        echo "[ERROR] UPLANETNAME not set - cannot encrypt" >&2
        return 1
    fi
    
    if [[ -z "$plaintext" ]]; then
        echo ""
        return 0
    fi
    
    # Generate key from UPLANETNAME (SHA256)
    local key=$(echo -n "$UPLANETNAME" | sha256sum | cut -d' ' -f1)
    
    # Generate random IV (16 bytes)
    local iv=$(openssl rand -hex 16)
    
    # Encrypt with AES-256-CBC
    local encrypted=$(echo -n "$plaintext" | openssl enc -aes-256-cbc -a -K "$key" -iv "$iv" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$encrypted" ]]; then
        echo "[ERROR] Encryption failed" >&2
        return 1
    fi
    
    # Return IV:encrypted (both base64-safe)
    echo "${iv}:${encrypted}"
}

# Decrypt a value with UPLANETNAME
# Usage: coop_decrypt "iv:encrypted_base64"
# Returns: plaintext
coop_decrypt() {
    local encrypted_data="$1"
    
    if [[ -z "$UPLANETNAME" ]]; then
        echo "[ERROR] UPLANETNAME not set - cannot decrypt" >&2
        return 1
    fi
    
    if [[ -z "$encrypted_data" ]]; then
        echo ""
        return 0
    fi
    
    # Extract IV and encrypted data
    local iv=$(echo "$encrypted_data" | cut -d':' -f1)
    local encrypted=$(echo "$encrypted_data" | cut -d':' -f2-)
    
    if [[ -z "$iv" ]] || [[ -z "$encrypted" ]]; then
        echo "[ERROR] Invalid encrypted data format (expected iv:encrypted)" >&2
        return 1
    fi
    
    # Generate key from UPLANETNAME (SHA256)
    local key=$(echo -n "$UPLANETNAME" | sha256sum | cut -d' ' -f1)
    
    # Decrypt with AES-256-CBC
    local plaintext=$(echo "$encrypted" | openssl enc -aes-256-cbc -d -a -K "$key" -iv "$iv" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Decryption failed - wrong UPLANETNAME or corrupted data" >&2
        return 1
    fi
    
    echo "$plaintext"
}

################################################################################
# DID NOSTR Functions
################################################################################

# Get the NPUB/HEX from uplanet.G1.nostr keyfile
coop_get_pubkey() {
    if [[ ! -f "$COOP_CONFIG_KEYFILE" ]]; then
        echo "[ERROR] Keyfile not found: $COOP_CONFIG_KEYFILE" >&2
        echo "[INFO] Run UPLANET.init.sh to create it" >&2
        return 1
    fi
    
    local hex=$(grep "HEX=" "$COOP_CONFIG_KEYFILE" 2>/dev/null | cut -d'=' -f2 | tr -d ';' | tr -d ' ')
    if [[ -z "$hex" ]]; then
        echo "[ERROR] Cannot extract HEX from keyfile" >&2
        return 1
    fi
    
    echo "$hex"
}

# Get the NSEC from uplanet.G1.nostr keyfile
coop_get_nsec() {
    if [[ ! -f "$COOP_CONFIG_KEYFILE" ]]; then
        echo "[ERROR] Keyfile not found: $COOP_CONFIG_KEYFILE" >&2
        return 1
    fi
    
    local nsec=$(grep "NSEC=" "$COOP_CONFIG_KEYFILE" 2>/dev/null | cut -d'=' -f2 | tr -d ';' | tr -d ' ')
    if [[ -z "$nsec" ]]; then
        echo "[ERROR] Cannot extract NSEC from keyfile" >&2
        return 1
    fi
    
    echo "$nsec"
}

# Fetch cooperative config DID from NOSTR
# Returns: JSON config object or empty
coop_fetch_config_from_nostr() {
    local pubkey=$(coop_get_pubkey) || return 1
    
    # Try local relay first, then remote
    local relays=("$COOP_CONFIG_LOCAL_RELAY" "$COOP_CONFIG_RELAY")
    
    for relay in "${relays[@]}"; do
        # Use nostr_get_events.sh if available
        if [[ -x "${MY_PATH}/nostr_get_events.sh" ]]; then
            local result=$("${MY_PATH}/nostr_get_events.sh" \
                --kind "$COOP_CONFIG_KIND" \
                --author "$pubkey" \
                --tag-d "$COOP_CONFIG_D_TAG" \
                --relay "$relay" \
                --limit 1 \
                --json 2>/dev/null)
            
            if [[ -n "$result" ]] && [[ "$result" != "[]" ]]; then
                # Extract content from the event
                local content=$(echo "$result" | jq -r '.[0].content // empty' 2>/dev/null)
                if [[ -n "$content" ]]; then
                    echo "$content"
                    return 0
                fi
            fi
        fi
        
        # Fallback: direct websocket query with Python
        if [[ -x "${MY_PATH}/nostr_cooperative_did.py" ]]; then
            local result=$(python3 "${MY_PATH}/nostr_cooperative_did.py" fetch \
                --relay "$relay" \
                --pubkey "$pubkey" \
                --d-tag "$COOP_CONFIG_D_TAG" 2>/dev/null)
            
            if [[ -n "$result" ]] && [[ "$result" != "null" ]]; then
                echo "$result"
                return 0
            fi
        fi
    done
    
    # Return empty JSON object if not found
    echo "{}"
    return 0
}

# Publish cooperative config DID to NOSTR
# Args: $1 = JSON config object
coop_publish_config_to_nostr() {
    local config_json="$1"
    local nsec=$(coop_get_nsec) || return 1
    
    if [[ -z "$config_json" ]]; then
        echo "[ERROR] No config JSON provided" >&2
        return 1
    fi
    
    # Validate JSON
    if ! echo "$config_json" | jq empty 2>/dev/null; then
        echo "[ERROR] Invalid JSON config" >&2
        return 1
    fi
    
    # Use nostr_send_note.py if available
    if [[ -x "${MY_PATH}/nostr_send_note.py" ]] || command -v python3 >/dev/null 2>&1; then
        local tags_json="[[\"d\", \"$COOP_CONFIG_D_TAG\"], [\"t\", \"cooperative-config\"], [\"t\", \"uplanet\"]]"
        
        local result=$(python3 "${MY_PATH}/nostr_send_note.py" \
            --keyfile "$COOP_CONFIG_KEYFILE" \
            --content "$config_json" \
            --tags "$tags_json" \
            --kind "$COOP_CONFIG_KIND" \
            --relays "$COOP_CONFIG_LOCAL_RELAY" "$COOP_CONFIG_RELAY" \
            --json 2>&1)
        
        if [[ $? -eq 0 ]]; then
            echo "[OK] Config published to NOSTR" >&2
            # Update local cache
            echo "$config_json" > "$COOP_CONFIG_CACHE"
            return 0
        else
            echo "[ERROR] Failed to publish config: $result" >&2
            return 1
        fi
    fi
    
    # Fallback: use nostr_cooperative_did.py
    if [[ -x "${MY_PATH}/nostr_cooperative_did.py" ]]; then
        python3 "${MY_PATH}/nostr_cooperative_did.py" publish \
            --keyfile "$COOP_CONFIG_KEYFILE" \
            --config "$config_json" \
            --relay "$COOP_CONFIG_LOCAL_RELAY" \
            --relay "$COOP_CONFIG_RELAY" 2>&1
        return $?
    fi
    
    echo "[ERROR] No NOSTR publish tool available" >&2
    return 1
}

################################################################################
# Cache Management
################################################################################

# Load config from cache or NOSTR
# Returns: JSON config object
coop_load_config() {
    local force_refresh="${1:-false}"
    local cache_max_age=3600  # 1 hour cache validity
    
    # Check cache first (if not forcing refresh)
    if [[ "$force_refresh" != "true" ]] && [[ -f "$COOP_CONFIG_CACHE" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$COOP_CONFIG_CACHE" 2>/dev/null || echo 0)))
        
        if [[ $cache_age -lt $cache_max_age ]]; then
            cat "$COOP_CONFIG_CACHE"
            return 0
        fi
    fi
    
    # Fetch from NOSTR
    local config=$(coop_fetch_config_from_nostr)
    
    if [[ -n "$config" ]] && [[ "$config" != "{}" ]]; then
        # Update cache
        mkdir -p "$(dirname "$COOP_CONFIG_CACHE")"
        echo "$config" > "$COOP_CONFIG_CACHE"
    fi
    
    echo "$config"
}

# Save config to cache and NOSTR
# Args: $1 = JSON config object
coop_save_config() {
    local config_json="$1"
    
    # Save to local cache
    mkdir -p "$(dirname "$COOP_CONFIG_CACHE")"
    echo "$config_json" > "$COOP_CONFIG_CACHE"
    
    # Publish to NOSTR
    coop_publish_config_to_nostr "$config_json"
}

################################################################################
# Public API Functions
################################################################################

# Get a config value (automatically decrypts sensitive values)
# Usage: coop_config_get "KEY_NAME"
# Returns: decrypted value or empty
coop_config_get() {
    local key="$1"
    
    if [[ -z "$key" ]]; then
        echo "[ERROR] Key name required" >&2
        return 1
    fi
    
    # Load config
    local config=$(coop_load_config)
    
    if [[ -z "$config" ]] || [[ "$config" == "{}" ]]; then
        return 1
    fi
    
    # Get encrypted value
    local encrypted_value=$(echo "$config" | jq -r --arg key "$key" '.[$key] // empty' 2>/dev/null)
    
    if [[ -z "$encrypted_value" ]]; then
        return 1
    fi
    
    # Check if value is encrypted (contains ":")
    if [[ "$encrypted_value" == *":"* ]]; then
        # Decrypt
        coop_decrypt "$encrypted_value"
    else
        # Return as-is (non-sensitive value)
        echo "$encrypted_value"
    fi
}

# Set a config value (automatically encrypts sensitive values)
# Usage: coop_config_set "KEY_NAME" "value" [--no-encrypt]
# Sensitive keys (containing TOKEN, SECRET, KEY, PASSWORD) are auto-encrypted
coop_config_set() {
    local key="$1"
    local value="$2"
    local no_encrypt="${3:-}"
    
    if [[ -z "$key" ]]; then
        echo "[ERROR] Key name required" >&2
        return 1
    fi
    
    # Load current config
    local config=$(coop_load_config)
    [[ -z "$config" ]] && config="{}"
    
    # Determine if value should be encrypted
    local final_value="$value"
    
    if [[ "$no_encrypt" != "--no-encrypt" ]]; then
        # Auto-encrypt sensitive keys
        if [[ "$key" == *"TOKEN"* ]] || \
           [[ "$key" == *"SECRET"* ]] || \
           [[ "$key" == *"KEY"* ]] || \
           [[ "$key" == *"PASSWORD"* ]] || \
           [[ "$key" == *"API"* ]]; then
            final_value=$(coop_encrypt "$value") || return 1
        fi
    fi
    
    # Update config JSON
    local new_config=$(echo "$config" | jq --arg key "$key" --arg val "$final_value" '.[$key] = $val' 2>/dev/null)
    
    if [[ -z "$new_config" ]]; then
        echo "[ERROR] Failed to update config JSON" >&2
        return 1
    fi
    
    # Save config
    coop_save_config "$new_config"
}

# Delete a config key
# Usage: coop_config_delete "KEY_NAME"
coop_config_delete() {
    local key="$1"
    
    if [[ -z "$key" ]]; then
        echo "[ERROR] Key name required" >&2
        return 1
    fi
    
    # Load current config
    local config=$(coop_load_config)
    [[ -z "$config" ]] && return 0
    
    # Remove key
    local new_config=$(echo "$config" | jq --arg key "$key" 'del(.[$key])' 2>/dev/null)
    
    # Save config
    coop_save_config "$new_config"
}

# List all config keys (shows encrypted keys with [ENCRYPTED] marker)
# Usage: coop_config_list
coop_config_list() {
    local config=$(coop_load_config)
    
    if [[ -z "$config" ]] || [[ "$config" == "{}" ]]; then
        echo "No cooperative config found."
        echo "Run: coop_config_set KEY VALUE to add configuration."
        return 0
    fi
    
    echo "=== Cooperative Configuration (UPLANETNAME_G1 DID) ==="
    echo ""
    
    # SECURITY: Keys that should ALWAYS be masked (even if stored unencrypted)
    # COOPERATIVE_NAME reveals $UPLANETNAME which is the encryption key!
    local sensitive_keys="COOPERATIVE_NAME"
    
    # List all keys with encryption status
    echo "$config" | jq -r --arg sensitive "$sensitive_keys" 'to_entries[] | 
        if (.key | inside($sensitive)) then
            "\(.key) = [SENSITIVE - HIDDEN]"
        elif (.value | test(":")) then
            "\(.key) = [ENCRYPTED]"
        else
            "\(.key) = \(.value)"
        end
    ' 2>/dev/null
    
    echo ""
    echo "DID: did:nostr:$(coop_get_pubkey 2>/dev/null || echo "unknown")"
    echo "D-tag: $COOP_CONFIG_D_TAG"
    echo "Cache: $COOP_CONFIG_CACHE"
}

# Show config in clear text (for debugging - be careful!)
# Usage: coop_config_show_decrypted
coop_config_show_decrypted() {
    local config=$(coop_load_config)
    
    if [[ -z "$config" ]] || [[ "$config" == "{}" ]]; then
        echo "No cooperative config found."
        return 0
    fi
    
    echo "=== Cooperative Configuration (DECRYPTED - SENSITIVE!) ==="
    echo ""
    
    # Decrypt and show all values
    for key in $(echo "$config" | jq -r 'keys[]' 2>/dev/null); do
        local value=$(coop_config_get "$key")
        echo "$key = $value"
    done
    
    echo ""
}

# Refresh config from NOSTR (force fetch)
# Usage: coop_config_refresh
coop_config_refresh() {
    echo "Refreshing cooperative config from NOSTR..."
    rm -f "$COOP_CONFIG_CACHE"
    local config=$(coop_load_config "true")
    
    if [[ -n "$config" ]] && [[ "$config" != "{}" ]]; then
        echo "[OK] Config refreshed"
        coop_config_list
    else
        echo "[WARN] No config found on NOSTR"
    fi
}

# Initialize default cooperative config
# Usage: coop_config_init [--force]
coop_config_init() {
    local force="${1:-}"
    
    # Check if config already exists
    local existing=$(coop_load_config)
    if [[ -n "$existing" ]] && [[ "$existing" != "{}" ]] && [[ "$force" != "--force" ]]; then
        echo "Cooperative config already exists. Use --force to overwrite."
        coop_config_list
        return 0
    fi
    
    echo "Initializing cooperative config..."
    
    # Create default config structure with ALL cooperative variables
    # These values MUST be the same across all swarm nodes
    # NOTE: COOPERATIVE_NAME is NOT stored - it would reveal the encryption key ($UPLANETNAME)
    # Each node already has $UPLANETNAME in their environment
    local default_config=$(cat <<EOF
{
    "COOPERATIVE_VERSION": "1.0",
    "CREATED_AT": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    
    "_comment_fiscal": "=== FISCAL PARAMETERS (legal requirements - must be uniform) ===",
    "TVA_RATE": "20.0",
    "IS_RATE_REDUCED": "15.0",
    "IS_RATE_NORMAL": "25.0",
    "IS_THRESHOLD": "42500",
    
    "_comment_shares": "=== COOPERATIVE SHARES (uniform pricing) ===",
    "ZENCARD_SATELLITE": "50",
    "ZENCARD_CONSTELLATION": "540",
    
    "_comment_3x13": "=== 3x1/3 RULE (constitutional - must be uniform) ===",
    "TREASURY_PERCENT": "33.33",
    "RND_PERCENT": "33.33",
    "ASSETS_PERCENT": "33.34",
    
    "_comment_oc": "=== OPENCOLLECTIVE (shared credentials - encrypted) ===",
    "OPENCOLLECTIVE_COLLECTIVE": "uplanet-zero",
    "OPENCOLLECTIVE_SLUG": "monnaie-libre"
}
EOF
)
    
    # Save to NOSTR
    coop_save_config "$default_config"
    
    echo ""
    echo "[OK] Default cooperative config initialized."
    echo ""
    echo "Cooperative variables now shared via DID NOSTR (kind 30800)"
    echo ""
    echo "To add sensitive credentials (will be encrypted with \$UPLANETNAME):"
    echo "  source ${MY_PATH}/cooperative_config.sh"
    echo "  coop_config_set OPENCOLLECTIVE_PERSONAL_TOKEN \"your_token\""
    echo "  coop_config_set OPENCOLLECTIVE_API_KEY \"your_api_key\""
    echo "  coop_config_set PLANTNET_API_KEY \"your_plantnet_key\""
    echo ""
}

################################################################################
# Load cooperative fiscal/economic variables into environment
# Call this at the start of scripts that need cooperative variables
################################################################################

# Load all cooperative variables into environment
# Usage: coop_load_env_vars
# This sets: TVA_RATE, IS_RATE_*, ZENCARD_*, *_PERCENT, OPENCOLLECTIVE_*, PLANTNET_API_KEY
coop_load_env_vars() {
    local config=$(coop_load_config 2>/dev/null)
    
    if [[ -z "$config" ]] || [[ "$config" == "{}" ]]; then
        echo "[WARN] No cooperative config found - using defaults" >&2
        return 1
    fi
    
    # Load fiscal parameters (non-encrypted)
    local val
    
    val=$(echo "$config" | jq -r '.TVA_RATE // empty' 2>/dev/null)
    [[ -n "$val" ]] && export TVA_RATE="$val"
    
    val=$(echo "$config" | jq -r '.IS_RATE_REDUCED // empty' 2>/dev/null)
    [[ -n "$val" ]] && export IS_RATE_REDUCED="$val"
    
    val=$(echo "$config" | jq -r '.IS_RATE_NORMAL // empty' 2>/dev/null)
    [[ -n "$val" ]] && export IS_RATE_NORMAL="$val"
    
    val=$(echo "$config" | jq -r '.IS_THRESHOLD // empty' 2>/dev/null)
    [[ -n "$val" ]] && export IS_THRESHOLD="$val"
    
    # Load cooperative shares
    val=$(echo "$config" | jq -r '.ZENCARD_SATELLITE // empty' 2>/dev/null)
    [[ -n "$val" ]] && export ZENCARD_SATELLITE="$val"
    
    val=$(echo "$config" | jq -r '.ZENCARD_CONSTELLATION // empty' 2>/dev/null)
    [[ -n "$val" ]] && export ZENCARD_CONSTELLATION="$val"
    
    # Load 3x1/3 percentages
    val=$(echo "$config" | jq -r '.TREASURY_PERCENT // empty' 2>/dev/null)
    [[ -n "$val" ]] && export TREASURY_PERCENT="$val" && export TREASURY_RATIO="$val"
    
    val=$(echo "$config" | jq -r '.RND_PERCENT // empty' 2>/dev/null)
    [[ -n "$val" ]] && export RND_PERCENT="$val" && export RND_RATIO="$val"
    
    val=$(echo "$config" | jq -r '.ASSETS_PERCENT // empty' 2>/dev/null)
    [[ -n "$val" ]] && export ASSETS_PERCENT="$val" && export ASSETS_RATIO="$val"
    
    # Load OpenCollective (non-sensitive)
    val=$(echo "$config" | jq -r '.OPENCOLLECTIVE_COLLECTIVE // empty' 2>/dev/null)
    [[ -n "$val" ]] && export OPENCOLLECTIVE_COLLECTIVE="$val"
    
    val=$(echo "$config" | jq -r '.OPENCOLLECTIVE_SLUG // empty' 2>/dev/null)
    [[ -n "$val" ]] && export OPENCOLLECTIVE_SLUG="$val"
    
    # Load encrypted credentials (auto-decrypted by coop_config_get)
    val=$(coop_config_get "OPENCOLLECTIVE_PERSONAL_TOKEN" 2>/dev/null)
    [[ -n "$val" ]] && export OPENCOLLECTIVE_PERSONAL_TOKEN="$val"
    
    val=$(coop_config_get "OPENCOLLECTIVE_API_KEY" 2>/dev/null)
    [[ -n "$val" ]] && export OPENCOLLECTIVE_API_KEY="$val"
    
    val=$(coop_config_get "PLANTNET_API_KEY" 2>/dev/null)
    [[ -n "$val" ]] && export PLANTNET_API_KEY="$val"
    
    return 0
}

################################################################################
# Convenience Functions for Common Config Values
################################################################################

# Get OpenCollective Personal Token
get_oc_token() {
    coop_config_get "OPENCOLLECTIVE_PERSONAL_TOKEN"
}

# Get OpenCollective Slug
get_oc_slug() {
    local slug=$(coop_config_get "OPENCOLLECTIVE_SLUG")
    echo "${slug:-monnaie-libre}"
}

# Get OpenCollective API Key (deprecated, for backward compatibility)
get_oc_api_key() {
    coop_config_get "OPENCOLLECTIVE_API_KEY"
}

################################################################################
# CLI Interface (when script is run directly)
################################################################################

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    case "${1:-}" in
        get)
            coop_config_get "$2"
            ;;
        set)
            coop_config_set "$2" "$3" "$4"
            ;;
        delete)
            coop_config_delete "$2"
            ;;
        list)
            coop_config_list
            ;;
        show)
            coop_config_show_decrypted
            ;;
        refresh)
            coop_config_refresh
            ;;
        init)
            coop_config_init "$2"
            ;;
        encrypt)
            coop_encrypt "$2"
            ;;
        decrypt)
            coop_decrypt "$2"
            ;;
        help|--help|-h)
            echo "cooperative_config.sh - Cooperative Configuration Manager via DID NOSTR"
            echo ""
            echo "Usage:"
            echo "  $0 get KEY              Get a config value (decrypted)"
            echo "  $0 set KEY VALUE        Set a config value (auto-encrypts sensitive keys)"
            echo "  $0 delete KEY           Delete a config key"
            echo "  $0 list                 List all config keys"
            echo "  $0 show                 Show all values decrypted (careful!)"
            echo "  $0 refresh              Force refresh from NOSTR"
            echo "  $0 init [--force]       Initialize default config"
            echo "  $0 encrypt VALUE        Encrypt a value (for testing)"
            echo "  $0 decrypt VALUE        Decrypt a value (for testing)"
            echo ""
            echo "As a library (source it):"
            echo "  source cooperative_config.sh"
            echo "  OC_TOKEN=\$(coop_config_get 'OPENCOLLECTIVE_PERSONAL_TOKEN')"
            echo "  coop_config_set 'MY_KEY' 'my_value'"
            echo ""
            echo "Environment:"
            echo "  UPLANETNAME      - Required for encryption/decryption"
            echo "  Keyfile          - $COOP_CONFIG_KEYFILE"
            echo "  Cache            - $COOP_CONFIG_CACHE"
            echo "  Relay            - $COOP_CONFIG_RELAY"
            ;;
        *)
            echo "Unknown command: ${1:-}"
            echo "Use '$0 help' for usage information."
            exit 1
            ;;
    esac
fi
