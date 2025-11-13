#!/bin/bash
###################################################################
# workflow_scheduler.sh
# Automatic scheduler for cookie-based workflows
#
# This script:
# - Queries NOSTR for scheduled workflows (kind 31900 with cron triggers)
# - Executes workflows based on cron expressions
# - Should be called periodically (e.g., every hour via cron)
#
# Usage: $0 [--check-all] [--user <email>]
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
exec 2>&1 >> ~/.zen/tmp/workflow_scheduler.log

# Source environment
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR. Astroport.ONE is missing !!" && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

CHECK_ALL="${1:-}"
USER_FILTER="${2:-}"

# Function to check if cron expression matches current time
check_cron_match() {
    local cron_expr="$1"
    
    # Parse cron expression: minute hour day month weekday
    # Format: "0 2 * * *" (daily at 2 AM)
    local cron_minute=$(echo "$cron_expr" | awk '{print $1}')
    local cron_hour=$(echo "$cron_expr" | awk '{print $2}')
    local cron_day=$(echo "$cron_expr" | awk '{print $3}')
    local cron_month=$(echo "$cron_expr" | awk '{print $4}')
    local cron_weekday=$(echo "$cron_expr" | awk '{print $5}')
    
    # Get current time
    local current_minute=$(date +%M)
    local current_hour=$(date +%H)
    local current_day=$(date +%d)
    local current_month=$(date +%m)
    local current_weekday=$(date +%w)  # 0=Sunday, 6=Saturday
    
    # Check minute
    if [[ "$cron_minute" != "*" ]] && [[ "$cron_minute" != "$current_minute" ]]; then
        return 1
    fi
    
    # Check hour
    if [[ "$cron_hour" != "*" ]] && [[ "$cron_hour" != "$current_hour" ]]; then
        return 1
    fi
    
    # Check day (simplified - doesn't handle all cron expressions)
    if [[ "$cron_day" != "*" ]] && [[ "$cron_day" != "$current_day" ]]; then
        return 1
    fi
    
    # Check month
    if [[ "$cron_month" != "*" ]] && [[ "$cron_month" != "$current_month" ]]; then
        return 1
    fi
    
    # Check weekday
    if [[ "$cron_weekday" != "*" ]] && [[ "$cron_weekday" != "$current_weekday" ]]; then
        return 1
    fi
    
    return 0
}

# Function to get workflows from NOSTR
get_scheduled_workflows() {
    local user_pubkey="$1"
    
    echo "Querying NOSTR for scheduled workflows..." >&2
    
    # Query strfry for kind 31900 events with cookie-workflow tag
    cd $HOME/.zen/strfry
    
    local query_json=""
    if [[ -n "$user_pubkey" ]]; then
        query_json='{"kinds":[31900],"authors":["'$user_pubkey'"],"#t":["cookie-workflow"]}'
    else
        query_json='{"kinds":[31900],"#t":["cookie-workflow"]}'
    fi
    
    local workflows=$(./strfry scan "$query_json" 2>/dev/null)
    cd - >/dev/null 2>&1
    
    if [[ -z "$workflows" ]]; then
        echo "No workflows found" >&2
        return 1
    fi
    
    # Parse workflows and filter for scheduled ones
    echo "$workflows" | jq -c 'if type == "array" then .[] else . end' 2>/dev/null | while IFS= read -r workflow_event; do
        [[ -z "$workflow_event" ]] && continue
        
        local workflow_content=$(echo "$workflow_event" | jq -r '.content' 2>/dev/null)
        if [[ -z "$workflow_content" ]] || ! echo "$workflow_content" | jq empty 2>/dev/null; then
            continue
        fi
        
        # Check if workflow has scheduled triggers
        local triggers=$(echo "$workflow_content" | jq -c '.triggers // []' 2>/dev/null)
        local has_schedule=$(echo "$triggers" | jq -c '.[] | select(.type == "schedule")' 2>/dev/null)
        
        if [[ -n "$has_schedule" ]]; then
            local workflow_id=$(echo "$workflow_event" | jq -r '.id' 2>/dev/null)
            local author=$(echo "$workflow_event" | jq -r '.pubkey' 2>/dev/null)
            local cron_expr=$(echo "$has_schedule" | jq -r '.cron // empty' 2>/dev/null)
            
            if [[ -n "$cron_expr" ]]; then
                echo "$workflow_id|$author|$cron_expr|$workflow_content"
            fi
        fi
    done
    
    return 0
}

# Function to execute workflow
execute_scheduled_workflow() {
    local workflow_id="$1"
    local author_pubkey="$2"
    local workflow_content="$3"
    
    echo "Executing scheduled workflow: $workflow_id" >&2
    
    # Get user email from pubkey
    local user_email=""
    local user_dir=""
    
    # Try to find user directory by pubkey
    local hex_pubkey=""
    if command -v python3 >/dev/null 2>&1; then
        # Try to convert npub to hex if needed
        if [[ ${#author_pubkey} -eq 64 ]]; then
            hex_pubkey="$author_pubkey"
        else
            # Assume it's npub, try to convert
            hex_pubkey=$(python3 -c "import sys; sys.path.insert(0, '$HOME/.zen/Astroport.ONE/tools'); from nostr2hex import npub_to_hex; print(npub_to_hex('$author_pubkey'))" 2>/dev/null || echo "$author_pubkey")
        fi
    else
        hex_pubkey="$author_pubkey"
    fi
    
    # Find user directory by hex pubkey
    if [[ -n "$hex_pubkey" ]]; then
        local nostr_base_path="$HOME/.zen/game/nostr"
        if [ -d "$nostr_base_path" ]; then
            for email_dir in "$nostr_base_path"/*; do
                if [ -d "$email_dir" ] && [[ -f "${email_dir}/HEX" ]]; then
                    local dir_hex=$(cat "${email_dir}/HEX" 2>/dev/null)
                    if [[ "$dir_hex" == "$hex_pubkey" ]]; then
                        user_dir="$email_dir"
                        user_email=$(basename "$email_dir")
                        break
                    fi
                fi
            done
        fi
    fi
    
    if [[ -z "$user_dir" ]] || [[ -z "$user_email" ]]; then
        echo "Warning: Could not find user directory for pubkey: $author_pubkey" >&2
        return 1
    fi
    
    echo "Found user: $user_email" >&2
    
    # Create execution request event (kind 31901)
    local exec_params=$(cat <<EOF
{
    "workflow_id": "$workflow_id",
    "trigger": "schedule",
    "parameters": {}
}
EOF
)
    
    # Execute workflow using cookie_workflow_engine.sh
    local result=$("$MY_PATH/cookie_workflow_engine.sh" "$workflow_id" "$user_email" "$author_pubkey" "scheduled_$(date +%s)" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "Workflow executed successfully: $workflow_id" >&2
    else
        echo "Workflow execution failed: $workflow_id" >&2
        echo "$result" >&2
    fi
    
    return $exit_code
}

# Main execution
main() {
    echo "========================================" >&2
    echo "Workflow Scheduler" >&2
    echo "Time: $(date)" >&2
    echo "========================================" >&2
    
    # Get user filter if provided
    local user_pubkey=""
    if [[ "$CHECK_ALL" == "--user" ]] && [[ -n "$USER_FILTER" ]]; then
        # Convert email to pubkey if needed
        local user_dir="$HOME/.zen/game/nostr/$USER_FILTER"
        if [[ -d "$user_dir" ]] && [[ -f "${user_dir}/HEX" ]]; then
            user_pubkey=$(cat "${user_dir}/HEX" 2>/dev/null)
        fi
    fi
    
    # Get scheduled workflows
    local workflows=$(get_scheduled_workflows "$user_pubkey")
    
    if [[ -z "$workflows" ]]; then
        echo "No scheduled workflows found" >&2
        exit 0
    fi
    
    # Check each workflow
    local executed_count=0
    while IFS='|' read -r workflow_id author_pubkey cron_expr workflow_content; do
        [[ -z "$workflow_id" ]] && continue
        
        echo "Checking workflow: $workflow_id (cron: $cron_expr)" >&2
        
        # Check if cron matches current time
        if check_cron_match "$cron_expr" || [[ "$CHECK_ALL" == "--check-all" ]]; then
            echo "Cron expression matches! Executing workflow..." >&2
            execute_scheduled_workflow "$workflow_id" "$author_pubkey" "$workflow_content"
            executed_count=$((executed_count + 1))
        else
            echo "Cron expression does not match current time" >&2
        fi
        
    done <<< "$workflows"
    
    echo "========================================" >&2
    echo "Scheduler completed: $executed_count workflow(s) executed" >&2
    echo "========================================" >&2
    
    exit 0
}

main "$@"

