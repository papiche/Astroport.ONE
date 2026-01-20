#!/bin/bash
# Dependencies : jq curl
#### image_to_video.sh : transform an image + prompt into a video using ComfyUI Wan2.2 14B i2v
#
# Usage: $0 <prompt> <image_url> [udrive_path]
#
# This script:
# 1. Downloads the source image from URL
# 2. Uploads it to ComfyUI input folder
# 3. Modifies the workflow with the prompt and image reference
# 4. Generates a video using Wan2.2 14B Image-to-Video model
# 5. Returns the IPFS URL of the generated video

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"
ME="${0##*/}"

# Check if required arguments are provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <prompt> <image_url> [udrive_path]" >&2
  echo "" >&2
  echo "  <prompt>      Description of the desired video animation" >&2
  echo "  <image_url>   URL of the source image (IPFS, HTTP, etc.)" >&2
  echo "  [udrive_path] Optional: uDRIVE path for output storage" >&2
  echo "" >&2
  echo "Example:" >&2
  echo "  $0 \"The character slowly turns their head\" https://ipfs.example.com/ipfs/Qm.../image.jpg" >&2
  exit 1
fi

# Optional uDRIVE path parameter
UDRIVE_PATH="$3"

. "${MY_PATH}/../tools/my.sh"

# Escape double quotes and backslashes in the prompt
PROMPT=$(echo "$1" | sed 's/"/\\"/g')
IMAGE_URL="$2"

# Workflow path for Wan2.2 14B Image-to-Video
WORKFLOW_PATH="$MY_PATH/workflow/video_wan2_2_14B_i2v.json"

if [ ! -f "$WORKFLOW_PATH" ]; then
  echo "Error: Workflow file not found: $WORKFLOW_PATH" >&2
  exit 1
fi

# Generate a random seed
generate_random_seed() {
  # Generate a random number between 0 and 2^53-1 (max safe integer in JavaScript)
  echo $((RANDOM * RANDOM * RANDOM))
}

# Create temporary directory if it doesn't exist
TMP_DIR="$HOME/.zen/tmp"
mkdir -p "$TMP_DIR"

# Determine output directory
if [ -n "$UDRIVE_PATH" ] && [ -d "$UDRIVE_PATH" ]; then
    OUTPUT_DIR="$UDRIVE_PATH"
    echo "Using uDRIVE directory: $OUTPUT_DIR" >&2
else
    OUTPUT_DIR="$TMP_DIR"
    echo "Using temporary directory: $OUTPUT_DIR" >&2
fi

# Generate unique ID for this execution
UNIQUE_ID=$(date +%s)_$(openssl rand -hex 4)
TMP_WORKFLOW="$TMP_DIR/workflow_i2v_${UNIQUE_ID}.json"
TMP_VIDEO="$OUTPUT_DIR/video_i2v_${UNIQUE_ID}.mp4"
TMP_IMAGE="$TMP_DIR/input_image_${UNIQUE_ID}"

# Cleanup temporary files on exit
cleanup() {
    rm -f "$TMP_WORKFLOW"
    rm -f "$TMP_IMAGE"*
    # Only remove TMP_VIDEO if it's in the temp directory, not in uDRIVE
    if [[ "$TMP_VIDEO" == "$TMP_DIR"* ]]; then
        rm -f "$TMP_VIDEO"
    fi
}
trap cleanup EXIT

# ComfyUI API address
COMFYUI_URL="http://127.0.0.1:8188"

# Extract host and port from URL
COMFYUI_HOST=$(echo "$COMFYUI_URL" | sed 's#http://##' | cut -d':' -f1)
COMFYUI_PORT=$(echo "$COMFYUI_URL" | sed 's#http://##' | cut -d':' -f2)

# Function to check if ComfyUI port is open
check_comfyui_port() {
  echo "Checking ComfyUI port: ${COMFYUI_HOST}:${COMFYUI_PORT}" >&2
  if nc -z "$COMFYUI_HOST" "$COMFYUI_PORT" > /dev/null 2>&1; then
    echo "ComfyUI port is accessible." >&2
    return 0
  else
    echo "Error: ComfyUI port is not accessible." >&2
    return 1
  fi
}

# Function to download and upload image to ComfyUI
prepare_image() {
  echo "Downloading source image from: $IMAGE_URL" >&2
  
  # Determine image extension from URL
  local extension=""
  case "$IMAGE_URL" in
    *.jpg|*.jpeg|*.JPG|*.JPEG) extension="jpg" ;;
    *.png|*.PNG) extension="png" ;;
    *.gif|*.GIF) extension="gif" ;;
    *.webp|*.WEBP) extension="webp" ;;
    *) extension="jpg" ;;  # Default to jpg
  esac
  
  TMP_IMAGE="${TMP_IMAGE}.${extension}"
  local image_filename="i2v_input_${UNIQUE_ID}.${extension}"
  
  # Download the image
  curl -sL -o "$TMP_IMAGE" "$IMAGE_URL"
  if [ $? -ne 0 ] || [ ! -s "$TMP_IMAGE" ]; then
    echo "Error: Failed to download image from $IMAGE_URL" >&2
    return 1
  fi
  
  echo "Image downloaded successfully: $TMP_IMAGE" >&2
  
  # Upload image to ComfyUI input folder
  echo "Uploading image to ComfyUI..." >&2
  
  local upload_response
  upload_response=$(curl -s -X POST -F "image=@${TMP_IMAGE};filename=${image_filename}" \
                    "$COMFYUI_URL/upload/image")
  
  if [ $? -ne 0 ]; then
    echo "Error: Failed to upload image to ComfyUI" >&2
    return 1
  fi
  
  # Parse response to get the actual filename used by ComfyUI
  local uploaded_name
  uploaded_name=$(echo "$upload_response" | jq -r '.name // empty')
  
  if [ -z "$uploaded_name" ]; then
    echo "Warning: Could not parse upload response, using original filename" >&2
    uploaded_name="$image_filename"
  fi
  
  echo "Image uploaded to ComfyUI as: $uploaded_name" >&2
  
  # Return the filename for use in workflow
  echo "$uploaded_name"
}

# Function to update prompt, image and seed in the workflow JSON
update_workflow() {
  local image_filename="$1"
  
  echo "Loading workflow JSON: ${WORKFLOW_PATH}" >&2

  # Generate a new random seed
  local new_seed=$(generate_random_seed)
  echo "Using random seed: $new_seed" >&2
  echo "Using image: $image_filename" >&2
  echo "Using prompt: $PROMPT" >&2

  # Create a modified JSON with:
  # - Node "93" (positive prompt): update text
  # - Node "97" (LoadImage): update image filename
  # - Node "86" (KSamplerAdvanced): update noise_seed
  jq --arg prompt "$PROMPT" \
     --arg image "$image_filename" \
     --argjson seed "$new_seed" \
     '
       (.["93"].inputs.text) = $prompt |
       (.["97"].inputs.image) = $image |
       (.["86"].inputs.noise_seed) = $seed
     ' \
     "$WORKFLOW_PATH" > "$TMP_WORKFLOW"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to modify workflow JSON" >&2
    return 1
  fi

  echo "Workflow updated in temporary JSON file: $TMP_WORKFLOW" >&2
  
  # Debug - show content of modified nodes
  echo "Modified nodes content:" >&2
  jq '.["93"].inputs.text, .["97"].inputs.image, .["86"].inputs.noise_seed' "$TMP_WORKFLOW" >&2
}

# Function to send workflow to ComfyUI API
send_workflow() {
  echo "Sending workflow to ComfyUI API..." >&2

  local response_body_file="$TMP_DIR/response_body_${UNIQUE_ID}.json"
  
  # Create proper API payload
  local api_payload_file="$TMP_DIR/api_payload_${UNIQUE_ID}.json"
  jq '{prompt: .}' "$TMP_WORKFLOW" > "$api_payload_file"
  
  echo "API request content (first 500 chars):" >&2
  head -c 500 "$api_payload_file" >&2
  echo >&2

  # Send the workflow to ComfyUI
  local http_status
  http_status=$(curl -s -w "%{http_code}" -o "$response_body_file" \
                -X POST -H "Content-Type: application/json" \
                --data-binary @"$api_payload_file" \
                "$COMFYUI_URL/prompt")
  
  # Clean up API payload file
  rm -f "$api_payload_file"
  
  local response_body
  response_body=$(cat "$response_body_file")
  rm -f "$response_body_file"

  echo "HTTP code: $http_status" >&2
  echo "API response: $response_body" >&2

  if [ "$http_status" -ne 200 ]; then
    echo "Error sending workflow, HTTP code: $http_status" >&2
    echo "API response (error details): $response_body" >&2
    exit 1
  fi

  echo "Workflow sent successfully." >&2
  local prompt_id
  prompt_id=$(echo "$response_body" | jq -r '.prompt_id')
  echo "Prompt ID: $prompt_id" >&2
  
  if [ -z "$prompt_id" ] || [ "$prompt_id" = "null" ]; then
    echo "Error: prompt_id not found in response." >&2
    echo "API response (error details): $response_body" >&2
    exit 1
  fi
  
  monitor_progress "$prompt_id"
}

# Function to monitor generation progress
monitor_progress() {
  local prompt_id="$1"
  local history_url="$COMFYUI_URL/history"
  local max_attempts=600  # 10 minutes maximum (i2v with 14B model takes longer)
  local attempts=0
  local start_time=$(date +%s)

  echo "Monitoring progress with ID: $prompt_id" >&2
  echo "Note: Wan2.2 14B i2v generation may take 3-8 minutes..." >&2

  # Wait for video generation
  while [ $attempts -lt $max_attempts ]; do
    # Calculate and display elapsed time
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    local minutes=$((elapsed_time / 60))
    local seconds=$((elapsed_time % 60))
    echo "Waiting for ComfyUI processing... (${minutes}m ${seconds}s)" >&2

    # Check history first to see if video is already done
    local history_response
    history_response=$(curl -s "$history_url")
    
    # Check if prompt_id exists in history
    if echo "$history_response" | jq -e --arg id "$prompt_id" '.[$id]' > /dev/null 2>&1; then
      echo "Video found in ComfyUI history!" >&2
      get_video_result "$prompt_id" "$elapsed_time"
      return $?
    fi
    
    # If not in history, check in queue
    local queue_response
    queue_response=$(curl -s "$COMFYUI_URL/prompt")
    
    # Check if running or queued
    if echo "$queue_response" | jq -e --arg id "$prompt_id" '.running[$id] or .pending[$id]' > /dev/null 2>&1; then
      echo "Video generation in progress or queued..." >&2
      sleep 10
      attempts=$((attempts + 10))
      continue
    fi
    
    # If not in queue or history yet, wait and check again
    sleep 10
    attempts=$((attempts + 10))
  done

  echo "Error: Timeout during video generation by ComfyUI." >&2
  return 1
}

# Function to retrieve and process the generated video
get_video_result() {
  local prompt_id="$1"
  local elapsed_time="$2"
  local history_url="$COMFYUI_URL/history"

  echo "Retrieving history..." >&2
  local history_response
  history_response=$(curl -s "$history_url")
  
  # Get output data for this specific prompt
  local prompt_data
  prompt_data=$(echo "$history_response" | jq --arg id "$prompt_id" '.[$id]')
  
  if [ -z "$prompt_data" ] || [ "$prompt_data" = "null" ]; then
    echo "Error: Prompt data not found in history" >&2
    return 1
  fi

  # Debug: Show complete output structure
  echo "Complete output structure:" >&2
  echo "$prompt_data" | jq '.outputs' >&2
  
  # Find the SaveVideo node (node 108 in video_wan2_2_14B_i2v.json)
  # Note: Some workflows output video files in "images" array (not "video")
  local video_node_outputs
  
  # Try node 108 first (primary node for i2v workflow)
  video_node_outputs=$(echo "$prompt_data" | jq '.outputs."108".video // .outputs."108".videos // .outputs."108".gifs // .outputs."108".images // empty')
  
  # Try node 58 as fallback
  if [ -z "$video_node_outputs" ] || [ "$video_node_outputs" = "null" ]; then
    video_node_outputs=$(echo "$prompt_data" | jq '.outputs."58".video // .outputs."58".videos // .outputs."58".gifs // .outputs."58".images // empty')
  fi
  
  # Try node 49 (VHS_VideoCombine)
  if [ -z "$video_node_outputs" ] || [ "$video_node_outputs" = "null" ]; then
    video_node_outputs=$(echo "$prompt_data" | jq '.outputs."49".gifs // .outputs."49".video // .outputs."49".images // empty')
  fi
  
  # Fallback: search for any node with video/gifs output
  if [ -z "$video_node_outputs" ] || [ "$video_node_outputs" = "null" ]; then
    echo "Known video nodes not found, searching for video outputs..." >&2
    video_node_outputs=$(echo "$prompt_data" | jq '[.outputs | to_entries[] | select(.value.video or .value.videos or .value.gifs) | .value.video // .value.videos // .value.gifs][0] // empty')
  fi
  
  # Final fallback: check images arrays for video files (.mp4, .webm, .gif)
  if [ -z "$video_node_outputs" ] || [ "$video_node_outputs" = "null" ]; then
    echo "Checking images arrays for video files..." >&2
    video_node_outputs=$(echo "$prompt_data" | jq '[.outputs | to_entries[] | select(.value.images) | .value.images | select(.[0].filename | test("\\.(mp4|webm|gif)$"; "i"))][0] // empty')
  fi
  
  if [ -z "$video_node_outputs" ] || [ "$video_node_outputs" = "null" ]; then
    echo "Error: Video output not found in any node" >&2
    echo "Available outputs for debug:" >&2
    echo "$prompt_data" | jq '.outputs | keys' >&2
    return 1
  fi
  
  # Get the video filename and subfolder
  local video_filename
  local video_subfolder
  video_filename=$(echo "$video_node_outputs" | jq -r '.[0].filename // .[0]')
  video_subfolder=$(echo "$video_node_outputs" | jq -r '.[0].subfolder // ""')
  
  if [ -z "$video_filename" ] || [ "$video_filename" = "null" ]; then
    echo "Error: Video filename not found in output" >&2
    return 1
  fi

  echo "Video filename: $video_filename" >&2
  echo "Subfolder: $video_subfolder" >&2
  
  # Build proper URL with correct ComfyUI API parameters
  # Format: /api/viewvideo?filename=<filename>&type=output&subfolder=<subfolder>
  local video_url
  if [ -z "$video_subfolder" ] || [ "$video_subfolder" = "null" ] || [ "$video_subfolder" = "" ]; then
    video_url="$COMFYUI_URL/api/viewvideo?filename=$video_filename&type=output"
  else
    video_url="$COMFYUI_URL/api/viewvideo?filename=$video_filename&type=output&subfolder=$video_subfolder"
  fi
  
  echo "Video URL: $video_url" >&2

  # Download the video from ComfyUI server
  echo "Downloading video..." >&2
  curl -s -o "$TMP_VIDEO" "$video_url"
  if [ $? -ne 0 ]; then
    echo "Error downloading video" >&2
    return 1
  fi
  echo "Video saved to $TMP_VIDEO" >&2

  # Verify video was downloaded correctly
  if [ ! -s "$TMP_VIDEO" ]; then
    echo "Error: Downloaded video is empty" >&2
    return 1
  fi

  # Add to IPFS
  echo "Adding video to IPFS..." >&2
  local ipfs_hash
  ipfs_hash=$(ipfs add -wq "$TMP_VIDEO" 2>/dev/null | tail -n 1)
  if [ -n "$ipfs_hash" ]; then
    echo "Video added to IPFS with hash: $ipfs_hash" >&2
    echo "Video saved to: $TMP_VIDEO" >&2
    
    # Output IPFS URL with generation time
    local minutes=$((elapsed_time / 60))
    local seconds=$((elapsed_time % 60))
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "🎬 $TIMESTAMP (⏱️ ${minutes}m ${seconds}s)\n📝 Description: $PROMPT\n🖼️ Source: $IMAGE_URL\n🔗 $myIPFS/ipfs/$ipfs_hash/$(basename "$TMP_VIDEO")"
    return 0
  else
    echo "Error adding video to IPFS" >&2
    return 1
  fi
}

# Main script execution

# Check if ComfyUI is accessible
check_comfyui_port
if [ $? -ne 0 ]; then
    exit 1
fi

# Prepare and upload the source image
IMAGE_FILENAME=$(prepare_image)
if [ $? -ne 0 ] || [ -z "$IMAGE_FILENAME" ]; then
    echo "Error: Failed to prepare source image" >&2
    exit 1
fi

# Update the workflow with the user's prompt and image
update_workflow "$IMAGE_FILENAME"
if [ $? -ne 0 ]; then
    exit 1
fi

# Send the workflow to ComfyUI for processing
send_workflow
