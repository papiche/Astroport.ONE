#!/bin/bash
################################################################################
# cookie_workflow_engine.sh
# Workflow execution engine for cookie-based automation
#
# Usage: $0 <workflow_identifier> <user_email> <pubkey> <event_id>
#
# This script:
# 1. Loads workflow definition from NOSTR (kind 31900)
# 2. Executes workflow nodes in sequence
# 3. Publishes execution result (kind 31902)
################################################################################

WORKFLOW_ID="$1"
USER_EMAIL="$2"
PUBKEY="$3"
EVENT_ID="$4"

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR. Astroport.ONE is missing !!" && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Load workflow from NOSTR
load_workflow_from_nostr() {
    local workflow_id="$1"
    log "Loading workflow from NOSTR: $workflow_id"
    
    cd "$HOME/.zen/strfry"
    local workflow_event=$(./strfry scan '{"kinds":[31900],"ids":["'"$workflow_id"'"]}' 2>/dev/null | jq -r 'select(.kind == 31900) | .' 2>/dev/null)
    cd - >/dev/null
    
    if [[ -z "$workflow_event" ]]; then
        log "ERROR: Workflow not found: $workflow_id"
        return 1
    fi
    
    echo "$workflow_event" | jq -r '.content' 2>/dev/null
}

# Execute cookie scraper node
execute_cookie_scraper() {
    local node="$1"
    local domain="${node[parameters][domain]}"
    local scraper="${node[parameters][scraper]}"
    local output_var="${node[parameters][output]}"
    
    log "Executing cookie scraper: $domain"
    
    # Find cookie file
    local cookie_file="$HOME/.zen/game/nostr/${USER_EMAIL}/.${domain}.cookie"
    
    if [[ ! -f "$cookie_file" ]]; then
        log "ERROR: Cookie file not found: $cookie_file"
        return 1
    fi
    
    # Execute scraper script
    local scraper_script="$MY_PATH/${domain}.sh"
    
    if [[ ! -f "$scraper_script" || ! -x "$scraper_script" ]]; then
        log "ERROR: Scraper script not found or not executable: $scraper_script"
        return 1
    fi
    
    # Run scraper and capture output
    local scraper_output=$("$scraper_script" "$USER_EMAIL" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "Cookie scraper executed successfully"
        # Return JSON output (scraper should output JSON)
        echo "$scraper_output"
        return 0
    else
        log "ERROR: Cookie scraper failed with exit code $exit_code"
        return 1
    fi
}

# Execute AI question node
execute_ai_question() {
    local node="$1"
    local prompt="${node[parameters][prompt]}"
    local model="${node[parameters][model]:-gemma3:12b}"
    local slot="${node[parameters][slot]:-0}"
    
    log "Executing AI question: $prompt"
    
    # Substitute variables in prompt
    # TODO: Implement variable substitution from previous nodes
    
    # Call question.py
    local ai_response=$("$MY_PATH/question.py" "$prompt" --model "$model" --slot "$slot" 2>&1)
    
    if [[ $? -eq 0 ]]; then
        log "AI question executed successfully"
        echo "$ai_response"
        return 0
    else
        log "ERROR: AI question failed"
        return 1
    fi
}

# Execute filter node
execute_filter() {
    local node="$1"
    local input_data="$2"
    local field="${node[parameters][field]}"
    local operator="${node[parameters][operator]}"
    local value="${node[parameters][value]}"
    
    log "Executing filter: $field $operator $value"
    
    # Use jq to filter JSON data
    local filtered_data=$(echo "$input_data" | jq --arg field "$field" --arg op "$operator" --arg val "$value" \
        'if type == "array" then 
            map(select(.[$field] | 
                if $op == "==" then . == $val
                elif $op == "!=" then . != $val
                elif $op == ">" then (. | tonumber) > ($val | tonumber)
                elif $op == "<" then (. | tonumber) < ($val | tonumber)
                elif $op == "contains" then (. | tostring) | contains($val)
                else true end
            ))
        else . end' 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        log "Filter executed successfully"
        echo "$filtered_data"
        return 0
    else
        log "ERROR: Filter execution failed"
        return 1
    fi
}

# Execute NOSTR publish node
execute_nostr_publish() {
    local node="$1"
    local content="${node[parameters][content_template]}"
    local kind="${node[parameters][kind]:-1}"
    local tags_json="${node[parameters][tags]:-[]}"
    
    log "Publishing NOSTR event (kind $kind)"
    
    # Substitute variables in content
    # TODO: Implement variable substitution
    
    # Parse tags
    local tags_array=$(echo "$tags_json" | jq -c '.' 2>/dev/null)
    
    if [[ -z "$tags_array" ]]; then
        tags_array='[]'
    fi
    
    # Get user's secret key
    local keyfile="$HOME/.zen/game/nostr/${USER_EMAIL}/.secret.nostr"
    
    if [[ ! -f "$keyfile" ]]; then
        log "ERROR: User secret key not found: $keyfile"
        return 1
    fi
    
    source "$keyfile"
    
    # Build tags JSON for nostr_send_note.py
    local tags_for_send=$(echo "$tags_array" | jq -c 'map(if type == "array" then . else [.] end)' 2>/dev/null)
    
    # Publish event
    local publish_result=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
        --keyfile "$keyfile" \
        --content "$content" \
        --relays "$myRELAY" \
        --tags "$tags_for_send" \
        --kind "$kind" \
        --json 2>&1)
    
    if [[ $? -eq 0 ]]; then
        local event_id=$(echo "$publish_result" | jq -r '.event_id // empty' 2>/dev/null)
        log "NOSTR event published successfully: $event_id"
        echo "{\"event_id\": \"$event_id\"}"
        return 0
    else
        log "ERROR: NOSTR publish failed: $publish_result"
        return 1
    fi
}

# Main workflow execution
main() {
    log "Starting cookie workflow execution: $WORKFLOW_ID"
    
    # Load workflow definition
    local workflow_json=$(load_workflow_from_nostr "$WORKFLOW_ID")
    
    if [[ -z "$workflow_json" ]]; then
        echo "ERROR: Failed to load workflow: $WORKFLOW_ID"
        exit 1
    fi
    
    # Parse workflow
    local workflow=$(echo "$workflow_json" | jq '.' 2>/dev/null)
    
    if [[ -z "$workflow" ]]; then
        echo "ERROR: Invalid workflow JSON"
        exit 1
    fi
    
    # Get nodes
    local nodes=$(echo "$workflow" | jq -c '.nodes // []' 2>/dev/null)
    local node_count=$(echo "$nodes" | jq 'length' 2>/dev/null)
    
    log "Workflow contains $node_count nodes"
    
    # Execute nodes in sequence (simplified - no dependency resolution yet)
    local node_results=()
    local execution_success=true
    
    for ((i=0; i<node_count; i++)); do
        local node=$(echo "$nodes" | jq -c ".[$i]" 2>/dev/null)
        local node_type=$(echo "$node" | jq -r '.type' 2>/dev/null)
        local node_id=$(echo "$node" | jq -r '.id' 2>/dev/null)
        
        log "Executing node $i: $node_id ($node_type)"
        
        local node_result=""
        local node_success=false
        
        case "$node_type" in
            cookie_scraper)
                node_result=$(execute_cookie_scraper "$node")
                node_success=$?
                ;;
            ai_question)
                node_result=$(execute_ai_question "$node")
                node_success=$?
                ;;
            filter)
                # Get input from previous node (simplified)
                local input_data="${node_results[$((i-1))]}"
                node_result=$(execute_filter "$node" "$input_data")
                node_success=$?
                ;;
            nostr_publish)
                # Get content from previous node
                local input_data="${node_results[$((i-1))]}"
                node_result=$(execute_nostr_publish "$node")
                node_success=$?
                ;;
            *)
                log "WARNING: Unknown node type: $node_type"
                node_result="{\"error\": \"Unknown node type: $node_type\"}"
                node_success=1
                ;;
        esac
        
        node_results[$i]="$node_result"
        
        if [[ $node_success -ne 0 ]]; then
            log "ERROR: Node execution failed: $node_id"
            execution_success=false
            break
        fi
    done
    
    # Publish execution result (kind 31902)
    if [[ "$execution_success" == true ]]; then
        log "Workflow execution completed successfully"
        echo "✅ Workflow executed successfully"
        exit 0
    else
        log "Workflow execution failed"
        echo "❌ Workflow execution failed"
        exit 1
    fi
}

# Run main function
main "$@"

