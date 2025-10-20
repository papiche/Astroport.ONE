#!/bin/bash
# HEX to Profile Converter using strfry
# This script converts HEX pubkeys to NOSTR profiles by fetching kind 0 and kind 3 events

## SET ASTROPORT ENVIRONNEMENT
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] \
    && echo "HEX TO PROFILE CONVERTER NEEDS ~/.zen/Astroport.ONE" \
    && exit 1

source ~/.zen/Astroport.ONE/tools/my.sh

# Configuration
SCRIPT_DIR="$HOME/.zen/workspace/NIP-101"
LOG_FILE="$HOME/.zen/tmp/hex-to-profile.log"
OUTPUT_DIR="$HOME/.zen/tmp/coucou"  # Long-term cache directory
JSON_OUTPUT="$OUTPUT_DIR/_NIP101.profiles.json"
CSV_OUTPUT="$OUTPUT_DIR/_NIP101.profiles.csv"

# Parse command line arguments
HEX_INPUT=""
VERBOSE=false
FORMAT="json"  # json, csv, or both
INCLUDE_RELAYS=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --hex)
            HEX_INPUT="$2"
            shift 2
            ;;
        --file)
            HEX_INPUT="file:$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --no-relays)
            INCLUDE_RELAYS=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--hex HEX] [--file FILE] [--verbose] [--format json|csv|both] [--no-relays]"
            echo ""
            echo "Options:"
            echo "  --hex HEX        Single HEX pubkey to convert"
            echo "  --file FILE       File containing HEX pubkeys (one per line)"
            echo "  --verbose         Show detailed output"
            echo "  --format FORMAT   Output format: json, csv, or both (default: json)"
            echo "  --no-relays       Exclude relay information (kind 3)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to log messages
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$VERBOSE" == "true" || "$level" == "ERROR" || "$level" == "WARN" ]]; then
        echo "[$timestamp] [$level] $message"
    fi
    
    # Always log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to get profile information for a HEX pubkey
get_profile_info() {
    local hex_pubkey="$1"
    local profile_data="{}"
    local relay_data="[]"
    
    log "INFO" "Fetching profile for HEX: ${hex_pubkey:0:8}..."
    
    # Check if strfry is available
    if [[ ! -x "$HOME/.zen/strfry/strfry" ]]; then
        log "ERROR" "strfry binary not found or not executable"
        return 1
    fi
    
    cd "$HOME/.zen/strfry"
    
    # Get kind 0 (profile) event
    log "DEBUG" "Fetching kind 0 (profile) for ${hex_pubkey:0:8}..."
    local profile_event=$(./strfry scan "{
        \"kinds\": [0],
        \"authors\": [\"$hex_pubkey\"],
        \"limit\": 1
    }" 2>/dev/null | jq -c 'select(.kind == 0) | {id: .id, pubkey: .pubkey, content: .content, created_at: .created_at, tags: .tags}' | head -1)
    
    if [[ -n "$profile_event" && "$profile_event" != "null" ]]; then
        log "DEBUG" "Found profile event for ${hex_pubkey:0:8}"
        
        # Parse profile content
        local profile_content=$(echo "$profile_event" | jq -r '.content' 2>/dev/null)
        if [[ -n "$profile_content" && "$profile_content" != "null" ]]; then
            # Try to parse as JSON, fallback to text
            if echo "$profile_content" | jq . >/dev/null 2>&1; then
                profile_data="$profile_content"
                log "DEBUG" "Parsed JSON profile for ${hex_pubkey:0:8}"
            else
                # Create a simple profile object from text content
                profile_data="{\"name\": \"$profile_content\", \"about\": \"$profile_content\"}"
                log "DEBUG" "Created text profile for ${hex_pubkey:0:8}"
            fi
        fi
    else
        log "WARN" "No profile (kind 0) found for ${hex_pubkey:0:8}"
    fi
    
    # Get kind 3 (relay list) event if requested
    if [[ "$INCLUDE_RELAYS" == "true" ]]; then
        log "DEBUG" "Fetching kind 3 (relays) for ${hex_pubkey:0:8}..."
        local relay_event=$(./strfry scan "{
            \"kinds\": [3],
            \"authors\": [\"$hex_pubkey\"],
            \"limit\": 1
        }" 2>/dev/null | jq -c 'select(.kind == 3) | {id: .id, pubkey: .pubkey, content: .content, created_at: .created_at, tags: .tags}' | head -1)
        
        if [[ -n "$relay_event" && "$relay_event" != "null" ]]; then
            log "DEBUG" "Found relay list for ${hex_pubkey:0:8}"
            
            # Extract relay information from tags
            relay_data=$(echo "$relay_event" | jq -c '.tags | map(select(.[0] == "r")) | map({url: .[1], read: (.[2] // "true"), write: (.[3] // "true")})' 2>/dev/null)
            if [[ -z "$relay_data" || "$relay_data" == "null" ]]; then
                relay_data="[]"
            fi
        else
            log "DEBUG" "No relay list (kind 3) found for ${hex_pubkey:0:8}"
        fi
    fi
    
    # Combine profile and relay data
    local combined_data=$(jq -n \
        --arg hex "$hex_pubkey" \
        --argjson profile "$profile_data" \
        --argjson relays "$relay_data" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            hex: $hex,
            profile: $profile,
            relays: $relays,
            fetched_at: $timestamp
        }' 2>/dev/null)
    
    if [[ -n "$combined_data" && "$combined_data" != "null" ]]; then
        echo "$combined_data"
        return 0
    else
        log "ERROR" "Failed to combine profile data for ${hex_pubkey:0:8}"
        return 1
    fi
}

# Function to convert profiles to CSV format
convert_to_csv() {
    local json_file="$1"
    local csv_file="$2"
    
    log "INFO" "Converting profiles to CSV format..."
    
    # Create CSV header
    echo "hex,name,display_name,about,picture,website,nip05,relays_count,relays_list,fetched_at" > "$csv_file"
    
    # Process each profile
    jq -r '.[] | [
        .hex,
        (.profile.name // ""),
        (.profile.display_name // ""),
        (.profile.about // ""),
        (.profile.picture // ""),
        (.profile.website // ""),
        (.profile.nip05 // ""),
        (.relays | length),
        (.relays | map(.url) | join(";")),
        .fetched_at
    ] | @csv' "$json_file" >> "$csv_file"
    
    log "INFO" "CSV file created: $csv_file"
}

# Function to display profile summary
display_profile_summary() {
    local json_file="$1"
    
    # Validate JSON file exists and is valid
    if [[ ! -f "$json_file" ]]; then
        echo "📊 Profile Summary:"
        echo "==================="
        echo "Total profiles: 0 (file not found)"
        echo "With names: 0"
        echo "With relays: 0"
        echo ""
        echo "🔍 Sample Profiles:"
        echo "==================="
        echo "(none)"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "📊 Profile Summary:"
        echo "==================="
        echo "Total profiles: 0 (invalid JSON)"
        echo "With names: 0"
        echo "With relays: 0"
        echo ""
        echo "🔍 Sample Profiles:"
        echo "==================="
        echo "(invalid JSON file)"
        return 1
    fi
    
    local total_profiles=$(jq -r 'length' "$json_file" 2>/dev/null || echo "0")
    local profiles_with_names=$(jq -r '[.[] | select(.profile.name != null and .profile.name != "")] | length' "$json_file" 2>/dev/null || echo "0")
    local profiles_with_relays=$(jq -r '[.[] | select(.relays | length > 0)] | length' "$json_file" 2>/dev/null || echo "0")
    
    echo "📊 Profile Summary:"
    echo "==================="
    echo "Total profiles: $total_profiles"
    echo "With names: $profiles_with_names"
    echo "With relays: $profiles_with_relays"
    echo ""
    
    # Show sample profiles
    echo "🔍 Sample Profiles:"
    echo "==================="
    if [[ $profiles_with_names -gt 0 ]]; then
        jq -r '.[] | select(.profile.name != null and .profile.name != "") | "\(.hex[0:8])... - \(.profile.name) (\(.profile.display_name // "no display name"))"' "$json_file" 2>/dev/null | head -10
    else
        echo "(no profiles with names)"
    fi
}

# Main execution
main() {
    log "INFO" "Starting HEX to Profile conversion"
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Get HEX pubkeys
    local hex_pubkeys=()
    
    if [[ -n "$HEX_INPUT" ]]; then
        if [[ "$HEX_INPUT" =~ ^file: ]]; then
            # Read from file
            local file_path="${HEX_INPUT#file:}"
            if [[ -f "$file_path" ]]; then
                while IFS= read -r line; do
                    line=$(echo "$line" | tr -d '[:space:]')
                    if [[ -n "$line" && ${#line} -eq 64 ]]; then
                        hex_pubkeys+=("$line")
                    fi
                done < "$file_path"
                log "INFO" "Loaded ${#hex_pubkeys[@]} HEX pubkeys from file: $file_path"
            else
                log "ERROR" "File not found: $file_path"
                exit 1
            fi
        else
            # Single HEX pubkey
            if [[ ${#HEX_INPUT} -eq 64 ]]; then
                hex_pubkeys+=("$HEX_INPUT")
                log "INFO" "Processing single HEX pubkey: ${HEX_INPUT:0:8}..."
            else
                log "ERROR" "Invalid HEX pubkey format: $HEX_INPUT"
                exit 1
            fi
        fi
    else
        log "ERROR" "No HEX input provided. Use --hex or --file option"
        exit 1
    fi
    
    if [[ ${#hex_pubkeys[@]} -eq 0 ]]; then
        log "ERROR" "No valid HEX pubkeys found"
        exit 1
    fi
    
    log "INFO" "Processing ${#hex_pubkeys[@]} HEX pubkeys"
    
    # Process each HEX pubkey
    local profiles=()
    local success_count=0
    
    for hex_pubkey in "${hex_pubkeys[@]}"; do
        log "INFO" "Processing HEX: ${hex_pubkey:0:8}..."
        
        if profile_data=$(get_profile_info "$hex_pubkey"); then
            profiles+=("$profile_data")
            ((success_count++))
            log "INFO" "✅ Successfully processed ${hex_pubkey:0:8}"
        else
            log "WARN" "❌ Failed to process ${hex_pubkey:0:8}"
        fi
    done
    
    if [[ ${#profiles[@]} -eq 0 ]]; then
        log "ERROR" "No profiles could be processed"
        exit 1
    fi
    
    # Combine all profiles into JSON array
    local json_output="["
    for i in "${!profiles[@]}"; do
        if [[ $i -gt 0 ]]; then
            json_output+=","
        fi
        json_output+="${profiles[$i]}"
    done
    json_output+="]"
    
    # Save JSON output
    echo "$json_output" | jq . > "$JSON_OUTPUT" 2>/dev/null
    log "INFO" "JSON profiles saved to: $JSON_OUTPUT"
    
    # Convert to CSV if requested
    if [[ "$FORMAT" == "csv" || "$FORMAT" == "both" ]]; then
        convert_to_csv "$JSON_OUTPUT" "$CSV_OUTPUT"
    fi
    
    # Display summary
    display_profile_summary "$JSON_OUTPUT"
    
    # Show output files
    echo ""
    echo "📁 Output Files:"
    echo "================"
    echo "JSON: $JSON_OUTPUT"
    if [[ "$FORMAT" == "csv" || "$FORMAT" == "both" ]]; then
        echo "CSV:  $CSV_OUTPUT"
    fi
    echo "Log:  $LOG_FILE"
    
    log "INFO" "Profile conversion completed: $success_count/${#hex_pubkeys[@]} successful"
}

# Run main function
main "$@"
