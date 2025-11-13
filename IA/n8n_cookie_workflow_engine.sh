#!/bin/bash
###################################################################
# cookie_workflow_engine.sh
# Workflow execution engine for cookie-based automation
#
# Usage: $0 <workflow_identifier> <user_email> <user_pubkey> <event_id>
#
# This script:
# - Loads workflow definition from NOSTR (kind 31900)
# - Executes workflow nodes in sequence
# - Uses cookies from user's MULTIPASS directory
# - Publishes results as NOSTR events
# - Supports BRO command generation in nostr_publish nodes
###################################################################

WORKFLOW_ID="$1"
USER_EMAIL="$2"
USER_PUBKEY="$3"
REQUEST_EVENT_ID="$4"

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
exec 2>&1 >> ~/.zen/tmp/cookie_workflow.log

# Source environment
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR. Astroport.ONE is missing !!" && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Function to get user directory from email
get_user_directory() {
    local email="$1"
    local nostr_base_path="$HOME/.zen/game/nostr"
    
    if [ -d "$nostr_base_path" ]; then
        for email_dir in "$nostr_base_path"/*; do
            if [ -d "$email_dir" ] && [[ "$email_dir" == *"$email"* ]]; then
                echo "$email_dir"
                return 0
            fi
        done
    fi
    
    return 1
}

# Function to find cookie file for domain
find_cookie_file() {
    local domain="$1"
    local user_dir="$2"
    
    if [[ -z "$user_dir" ]] || [[ ! -d "$user_dir" ]]; then
        echo "Error: User directory not found" >&2
        return 1
    fi
    
    local cookie_file="${user_dir}/.${domain}.cookie"
    
    if [[ -f "$cookie_file" ]]; then
        echo "$cookie_file"
        return 0
    else
        echo "Error: Cookie file not found: $cookie_file" >&2
        return 1
    fi
}

# Function to get event by ID from strfry
get_event_by_id() {
    local event_id="$1"
    cd $HOME/.zen/strfry
    ./strfry scan '{"ids":["'"$event_id"'"]}' 2>/dev/null
    cd - >/dev/null 2>&1
}

# Function to load workflow from NOSTR
load_workflow() {
    local workflow_id="$1"
    
    echo "Loading workflow: $workflow_id" >&2
    
    # Try to get workflow by ID first
    local workflow_event=$(get_event_by_id "$workflow_id")
    
    if [[ -z "$workflow_event" ]]; then
        # Try to find by name (query kind 31900 with tag)
        echo "Workflow not found by ID, trying to find by name..." >&2
        # This would require a more complex query - for now, return error
        return 1
    fi
    
    # Check if it's a kind 31900 event
    local kind=$(echo "$workflow_event" | jq -r '.kind // empty' 2>/dev/null)
    if [[ "$kind" != "31900" ]]; then
        echo "Error: Event is not a workflow definition (kind 31900)" >&2
        return 1
    fi
    
    # Extract workflow JSON from content
    local workflow_json=$(echo "$workflow_event" | jq -r '.content' 2>/dev/null)
    
    if [[ -z "$workflow_json" ]] || ! echo "$workflow_json" | jq empty 2>/dev/null; then
        echo "Error: Invalid workflow JSON" >&2
        return 1
    fi
    
    echo "$workflow_json"
    return 0
}

# Function to execute cookie scraper node
execute_cookie_scraper() {
    local node="$1"
    local user_dir="$2"
    
    local domain=$(echo "$node" | jq -r '.parameters.domain // empty' 2>/dev/null)
    local scraper=$(echo "$node" | jq -r '.parameters.scraper // empty' 2>/dev/null)
    local output_var=$(echo "$node" | jq -r '.parameters.output // "data"' 2>/dev/null)
    
    if [[ -z "$domain" ]]; then
        echo "Error: cookie_scraper node missing domain parameter" >&2
        return 1
    fi
    
    # Find cookie file
    local cookie_file=$(find_cookie_file "$domain" "$user_dir")
    if [[ $? -ne 0 ]]; then
        echo "Error: Cookie file not found for domain: $domain" >&2
        return 1
    fi
    
    echo "Executing scraper for domain: $domain" >&2
    
    # Find scraper script
    local scraper_script=""
    if [[ -n "$scraper" ]]; then
        # Look for scraper in IA directory
        if [[ -f "$MY_PATH/$scraper" ]]; then
            scraper_script="$MY_PATH/$scraper"
        elif [[ -f "$MY_PATH/../scrapers/$scraper" ]]; then
            scraper_script="$MY_PATH/../scrapers/$scraper"
        fi
    else
        # Default: try domain.sh
        if [[ -f "$MY_PATH/${domain}.sh" ]]; then
            scraper_script="$MY_PATH/${domain}.sh"
        elif [[ -f "$MY_PATH/../scrapers/${domain}.sh" ]]; then
            scraper_script="$MY_PATH/../scrapers/${domain}.sh"
        fi
    fi
    
    if [[ -z "$scraper_script" ]] || [[ ! -f "$scraper_script" ]]; then
        echo "Error: Scraper script not found: $scraper" >&2
        return 1
    fi
    
    # Execute scraper with cookie file
    echo "Running scraper: $scraper_script with cookie: $cookie_file" >&2
    local result=$("$scraper_script" "$cookie_file" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Scraper failed with exit code $exit_code" >&2
        echo "$result" >&2
        return 1
    fi
    
    # Return result as JSON
    echo "$result" | jq -c '.' 2>/dev/null || echo "{\"raw\":\"$result\"}"
    return 0
}

# Function to execute AI question node
execute_ai_question() {
    local node="$1"
    local input_data="$2"
    
    local prompt=$(echo "$node" | jq -r '.parameters.prompt // ""' 2>/dev/null)
    local model=$(echo "$node" | jq -r '.parameters.model // "gemma3:12b"' 2>/dev/null)
    local slot=$(echo "$node" | jq -r '.parameters.slot // 0' 2>/dev/null)
    
    if [[ -z "$prompt" ]]; then
        echo "Error: ai_question node missing prompt parameter" >&2
        return 1
    fi
    
    # Substitute variables in prompt from input_data
    local final_prompt="$prompt"
    if [[ -n "$input_data" ]] && echo "$input_data" | jq empty 2>/dev/null; then
        # Extract values from JSON and substitute
        while IFS= read -r key; do
            local value=$(echo "$input_data" | jq -r ".$key // empty" 2>/dev/null)
            if [[ -n "$value" ]]; then
                final_prompt=$(echo "$final_prompt" | sed "s/{$key}/$value/g")
            fi
        done < <(echo "$input_data" | jq -r 'keys[]' 2>/dev/null)
    fi
    
    echo "Asking AI: $final_prompt" >&2
    
    # Call question.py
    local result=$("$MY_PATH/question.py" "$final_prompt" --model "$model" --slot "$slot" --pubkey "$USER_PUBKEY" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "Error: AI question failed" >&2
        return 1
    fi
    
    # Extract answer from JSON if needed
    local answer=$(echo "$result" | jq -r '.answer // .' 2>/dev/null || echo "$result")
    echo "$answer"
    return 0
}

# Function to execute filter node
execute_filter() {
    local node="$1"
    local input_data="$2"
    
    local field=$(echo "$node" | jq -r '.parameters.field // ""' 2>/dev/null)
    local operator=$(echo "$node" | jq -r '.parameters.operator // "=="' 2>/dev/null)
    local value=$(echo "$node" | jq -r '.parameters.value // ""' 2>/dev/null)
    
    if [[ -z "$field" ]] || [[ -z "$input_data" ]]; then
        echo "Error: filter node missing parameters or input data" >&2
        return 1
    fi
    
    # Filter JSON array
    local filtered=$(echo "$input_data" | jq -c --arg field "$field" --arg op "$operator" --arg val "$value" \
        'if type == "array" then 
            map(select(
                if $op == "==" then .[$field] == $val
                elif $op == "!=" then .[$field] != $val
                elif $op == ">" then (.[$field] | tonumber) > ($val | tonumber)
                elif $op == "<" then (.[$field] | tonumber) < ($val | tonumber)
                elif $op == "contains" then (.[$field] | tostring) | contains($val)
                else true
                end
            ))
        else . end' 2>/dev/null)
    
    if [[ -z "$filtered" ]]; then
        echo "[]"
        return 0
    fi
    
    echo "$filtered"
    return 0
}

# Function to execute NOSTR publish node (with BRO command support)
execute_nostr_publish() {
    local node="$1"
    local input_data="$2"
    local user_dir="$3"
    
    local kind=$(echo "$node" | jq -r '.parameters.kind // 1' 2>/dev/null)
    local tags=$(echo "$node" | jq -r '.parameters.tags // "[]"' 2>/dev/null)
    local content_template=$(echo "$node" | jq -r '.parameters.content_template // ""' 2>/dev/null)
    local send_bro=$(echo "$node" | jq -r '.parameters.send_bro // false' 2>/dev/null)
    
    # Substitute variables in content template
    local content="$content_template"
    if [[ -n "$input_data" ]] && echo "$input_data" | jq empty 2>/dev/null; then
        while IFS= read -r key; do
            local value=$(echo "$input_data" | jq -r ".$key // empty" 2>/dev/null)
            if [[ -n "$value" ]]; then
                content=$(echo "$content" | sed "s/{$key}/$value/g")
            fi
        done < <(echo "$input_data" | jq -r 'keys[]' 2>/dev/null)
    fi
    
    # If send_bro is true, prepend #BRO to content
    if [[ "$send_bro" == "true" ]]; then
        content="#BRO $content"
        echo "Adding #BRO tag to trigger UPlanet_IA_Responder.sh" >&2
    fi
    
    # Get user's NOSTR key
    local keyfile=""
    if [[ -n "$user_dir" ]] && [[ -f "${user_dir}/.secret.nostr" ]]; then
        keyfile="${user_dir}/.secret.nostr"
    else
        echo "Error: User NOSTR key not found" >&2
        return 1
    fi
    
    # Parse tags JSON
    local tags_json=""
    if echo "$tags" | jq empty 2>/dev/null; then
        tags_json="$tags"
    else
        # Try to parse as string array
        tags_json=$(echo "$tags" | jq -c '.' 2>/dev/null || echo '[]')
    fi
    
    # Add standard tags
    local standard_tags='[["e","'$REQUEST_EVENT_ID'"],["p","'$USER_PUBKEY'"]]'
    if [[ "$tags_json" != "[]" ]] && [[ -n "$tags_json" ]]; then
        tags_json=$(echo "$standard_tags" | jq -c --argjson extra "$tags_json" '. + $extra' 2>/dev/null || echo "$standard_tags")
    else
        tags_json="$standard_tags"
    fi
    
    echo "Publishing NOSTR event (kind: $kind)" >&2
    
    # Publish using nostr_send_note.py
    local result=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
        --keyfile "$keyfile" \
        --content "$content" \
        --relays "$myRELAY" \
        --tags "$tags_json" \
        --kind "$kind" \
        --json 2>&1)
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        local event_id=$(echo "$result" | jq -r '.event_id // empty' 2>/dev/null)
        echo "Published event: $event_id" >&2
        echo "$event_id"
        return 0
    else
        echo "Error: Failed to publish NOSTR event" >&2
        echo "$result" >&2
        return 1
    fi
}

# Function to execute workflow nodes
execute_workflow() {
    local workflow_json="$1"
    local user_dir="$2"
    
    # Get nodes and connections
    local nodes=$(echo "$workflow_json" | jq -c '.nodes // []' 2>/dev/null)
    local connections=$(echo "$workflow_json" | jq -c '.connections // []' 2>/dev/null)
    
    # Build execution order (topological sort)
    # For now, simple sequential execution based on connections
    declare -A node_outputs
    
    # Find source nodes (no inputs)
    local source_nodes=$(echo "$nodes" | jq -c '.[] | select(.connections.input == null or .connections.input == [])' 2>/dev/null)
    
    # Execute nodes
    while IFS= read -r node_json; do
        [[ -z "$node_json" ]] && continue
        
        local node_id=$(echo "$node_json" | jq -r '.id // empty' 2>/dev/null)
        local node_type=$(echo "$node_json" | jq -r '.type // empty' 2>/dev/null)
        
        echo "Executing node: $node_id ($node_type)" >&2
        
        # Get input data from connected nodes
        local input_data=""
        local input_connections=$(echo "$node_json" | jq -r '.connections.input // []' 2>/dev/null)
        if [[ -n "$input_connections" ]] && [[ "$input_connections" != "[]" ]]; then
            # Get data from first input connection
            local first_input=$(echo "$input_connections" | jq -r '.[0] // empty' 2>/dev/null)
            if [[ -n "$first_input" ]] && [[ -n "${node_outputs[$first_input]}" ]]; then
                input_data="${node_outputs[$first_input]}"
            fi
        fi
        
        # Execute node based on type
        local result=""
        case "$node_type" in
            cookie_scraper)
                result=$(execute_cookie_scraper "$node_json" "$user_dir")
                ;;
            ai_question)
                result=$(execute_ai_question "$node_json" "$input_data")
                ;;
            filter)
                result=$(execute_filter "$node_json" "$input_data")
                ;;
            nostr_publish)
                result=$(execute_nostr_publish "$node_json" "$input_data" "$user_dir")
                ;;
            *)
                echo "Warning: Unknown node type: $node_type" >&2
                result="{\"status\":\"skipped\",\"type\":\"$node_type\"}"
                ;;
        esac
        
        # Store output
        if [[ -n "$result" ]]; then
            node_outputs["$node_id"]="$result"
        fi
        
    done < <(echo "$nodes" | jq -c '.[]' 2>/dev/null)
    
    # Return final results
    echo "Workflow execution completed" >&2
    for node_id in "${!node_outputs[@]}"; do
        echo "Node $node_id: ${node_outputs[$node_id]}" >&2
    done
    
    return 0
}

# Main execution
main() {
    if [[ $# -lt 4 ]]; then
        echo "Usage: $0 <workflow_id> <user_email> <user_pubkey> <request_event_id>"
        exit 1
    fi
    
    echo "========================================" >&2
    echo "Cookie Workflow Engine" >&2
    echo "Workflow ID: $WORKFLOW_ID" >&2
    echo "User: $USER_EMAIL" >&2
    echo "========================================" >&2
    
    # Get user directory
    local user_dir=$(get_user_directory "$USER_EMAIL")
    if [[ -z "$user_dir" ]]; then
        echo "Error: User directory not found for: $USER_EMAIL" >&2
        exit 1
    fi
    
    echo "User directory: $user_dir" >&2
    
    # Load workflow
    local workflow_json=$(load_workflow "$WORKFLOW_ID")
    if [[ $? -ne 0 ]] || [[ -z "$workflow_json" ]]; then
        echo "Error: Failed to load workflow: $WORKFLOW_ID" >&2
        exit 1
    fi
    
    echo "Workflow loaded successfully" >&2
    
    # Execute workflow
    execute_workflow "$workflow_json" "$user_dir"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "Workflow executed successfully" >&2
    else
        echo "Workflow execution failed" >&2
    fi
    
    exit $exit_code
}

main "$@"

