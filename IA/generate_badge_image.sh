#!/bin/bash
###################################################################
# generate_badge_image.sh
# Generate badge images automatically for Oracle permits and ORE contracts
#
# Usage: $0 <badge_id> <permit_name> <permit_description> [level] [label]
#
# Input:
#   - badge_id: Unique badge identifier (e.g., "ore_verifier", "permit_maitre_nageur_x5")
#   - permit_name: Name of the permit (e.g., "ORE Verifier", "Maître Nageur")
#   - permit_description: Description of the permit
#   - level: Optional WoTx2 level (e.g., "X5", "X10") for level-specific badges
#   - label: Optional level label (e.g., "Expert", "Maître", "Grand Maître")
#
# Output:
#   - Returns JSON with image URLs:
#     {
#       "badge_image_url": "https://ipfs.copylaradio.com/ipfs/QmHash/badge_id.png",
#       "badge_thumb_256": "https://ipfs.copylaradio.com/ipfs/QmHash/badge_id_256x256.png",
#       "badge_thumb_64": "https://ipfs.copylaradio.com/ipfs/QmHash/badge_id_64x64.png"
#     }
#
# Process:
#   1. Generate Stable Diffusion prompt using question.py (AI-powered)
#   2. Generate main badge image (1024x1024) using generate_image.sh
#   3. Generate thumbnails (256x256, 64x64) using ImageMagick
#   4. Upload all images to IPFS
#   5. Return IPFS URLs
#
# Badge Design Guidelines:
#   - Official Permits: Green/Blue/Gold color scheme
#   - WoTx2 X1-X4: Bronze/Copper
#   - WoTx2 X5-X10: Silver
#   - WoTx2 X11-X50: Gold
#   - WoTx2 X51-X100: Platinum/Diamond
#   - WoTx2 X101+: Rainbow/Multicolor
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Validate input parameters
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <badge_id> <permit_name> <permit_description> [level] [label]" >&2
    echo "Example: $0 ore_verifier 'ORE Verifier' 'Environmental verification permit' '' ''" >&2
    echo "Example: $0 permit_maitre_nageur_x5 'Maître Nageur' 'Swimming instructor' 'X5' 'Expert'" >&2
    exit 1
fi

BADGE_ID="$1"
PERMIT_NAME="$2"
PERMIT_DESCRIPTION="$3"
LEVEL="${4:-}"
LABEL="${5:-}"

# Source environment
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR: Astroport.ONE is missing !!" >&2 && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Get IPFS gateway
myipfs="${myIPFS:-https://ipfs.copylaradio.com}"

# Temporary directory for badge generation
BADGE_TMP_DIR="$HOME/.zen/tmp/badges"
mkdir -p "$BADGE_TMP_DIR"

# Output directory for badges (IPFS)
BADGE_OUTPUT_DIR="$HOME/.zen/tmp/badges_output"
mkdir -p "$BADGE_OUTPUT_DIR"

# Function to determine color scheme based on level
get_color_scheme() {
    local level="$1"
    local label="$2"
    
    if [[ -z "$level" ]]; then
        # Official permit - use green/blue/gold
        echo "green gradient, blue accents, gold highlights, professional, authoritative"
        return
    fi
    
    # Extract numeric level
    local level_num=$(echo "$level" | sed 's/X//' | tr -d '[:alpha:]')
    
    if [[ -z "$level_num" ]] || [[ "$level_num" -le 4 ]]; then
        echo "bronze, copper, warm brown, metallic, beginner level"
    elif [[ "$level_num" -le 10 ]]; then
        echo "silver, metallic gray, polished, expert level"
    elif [[ "$level_num" -le 50 ]]; then
        echo "gold, yellow gold, bright, master level, prestigious"
    elif [[ "$level_num" -le 100 ]]; then
        echo "platinum, diamond, white gold, brilliant, grand master level, elite"
    else
        echo "rainbow gradient, multicolor, vibrant, absolute master level, legendary"
    fi
}

# Function to generate Stable Diffusion prompt using AI
generate_sd_prompt() {
    local badge_id="$1"
    local permit_name="$2"
    local permit_description="$3"
    local level="$4"
    local label="$5"
    
    local color_scheme=$(get_color_scheme "$level" "$label")
    
    # Build context for AI prompt generation
    local badge_context=""
    if [[ -n "$level" && -n "$label" ]]; then
        badge_context="Badge for permit: ${permit_name} - Level ${level} (${label}). Description: ${permit_description}. Color scheme: ${color_scheme}."
    else
        badge_context="Official permit badge: ${permit_name}. Description: ${permit_description}. Color scheme: ${color_scheme}."
    fi
    
    # Generate Stable Diffusion prompt using question.py
    echo "Generating Stable Diffusion prompt using AI..." >&2
    
    local ai_prompt="Create a Stable Diffusion prompt for a professional badge image. 
    
Badge details:
- Name: ${permit_name}
- Description: ${permit_description}
${level:+- Level: ${level} (${label})}
- Color scheme: ${color_scheme}
- Style: Professional certification badge, circular or shield shape, high quality, detailed, suitable for digital display

CRITICAL RULES:
1. Output ONLY the prompt text, no explanations
2. NO emojis, NO special characters, NO text overlays, NO words, NO writing in the image
3. ONLY visual elements: shapes, colors, icons, symbols, patterns
4. Use simple English words only
5. Focus on: badge shape (circular/shield), color scheme, decorative elements, professional appearance
6. Badge should look like a certification badge or medal, not a logo
7. Include level indicator if level is provided (visual representation, not text)
8. Make it visually distinct and recognizable"

    # Call question.py to generate the prompt
    local sd_prompt_result
    sd_prompt_result=$("$MY_PATH/question.py" --json "$ai_prompt" --pubkey "" 2>/dev/null)
    
    if [[ $? -eq 0 && -n "$sd_prompt_result" ]]; then
        # Extract prompt from JSON response
        local sd_prompt=$(echo "$sd_prompt_result" | jq -r '.answer // .' 2>/dev/null || echo "$sd_prompt_result")
        
        # Clean the prompt
        sd_prompt=$(echo "$sd_prompt" | \
            sed 's/^[[:space:]]*//' | \
            sed 's/[[:space:]]*$//' | \
            sed 's/\s\+/ /g' | \
            sed 's/emoji//g' | \
            sed 's/emojis//g' | \
            head -c 500)
        
        if [[ -n "$sd_prompt" && ${#sd_prompt} -gt 20 ]]; then
            echo "$sd_prompt"
            return 0
        fi
    fi
    
    # Fallback: Generate a basic prompt if AI fails
    echo "Warning: AI prompt generation failed, using fallback prompt" >&2
    local fallback_prompt="professional certification badge, ${color_scheme}, circular shape, detailed, high quality, digital art, clean design"
    echo "$fallback_prompt"
    return 1
}

# Function to generate badge image
generate_badge_image() {
    local badge_id="$1"
    local sd_prompt="$2"
    
    echo "Generating badge image with ComfyUI..." >&2
    
    # Ensure ComfyUI is running
    "$MY_PATH/comfyui.me.sh" >/dev/null 2>&1
    
    # Generate image using generate_image.sh
    local image_url
    image_url=$("$MY_PATH/generate_image.sh" "$sd_prompt" "$BADGE_TMP_DIR" 2>&1)
    
    local gen_exit_code=$?
    if [[ $gen_exit_code -eq 0 && -n "$image_url" ]]; then
        # Extract local file path from IPFS URL or find the generated file
        local image_file=""
        
        # Try to find the image file in temp directory (most recent)
        local latest_image=$(ls -t "$BADGE_TMP_DIR"/image_*.png 2>/dev/null | head -1)
        if [[ -n "$latest_image" && -f "$latest_image" ]]; then
            image_file="$latest_image"
            echo "Found generated image: $image_file" >&2
        else
            # Try to extract IPFS hash from URL and download
            echo "Warning: Local image file not found, extracting from IPFS URL..." >&2
            local ipfs_hash=$(echo "$image_url" | grep -oP '/ipfs/\K[^/]+' | head -1)
            if [[ -n "$ipfs_hash" ]]; then
                # Try to get filename from URL
                local filename=$(echo "$image_url" | grep -oP '/ipfs/[^/]+/\K[^/]+' | head -1)
                if [[ -z "$filename" ]]; then
                    filename="${badge_id}.png"
                fi
                image_file="$BADGE_TMP_DIR/${badge_id}_${ipfs_hash}.png"
                echo "Downloading from IPFS: ${myipfs}/ipfs/${ipfs_hash}/${filename}" >&2
                curl -s -L "${myipfs}/ipfs/${ipfs_hash}/${filename}" -o "$image_file" 2>/dev/null
                
                # If download failed, try without filename
                if [[ ! -f "$image_file" || ! -s "$image_file" ]]; then
                    curl -s -L "${myipfs}/ipfs/${ipfs_hash}" -o "$image_file" 2>/dev/null
                fi
            fi
        fi
        
        if [[ -n "$image_file" && -f "$image_file" && -s "$image_file" ]]; then
            echo "$image_file"
            return 0
        else
            echo "Error: Generated image file not found or empty" >&2
        fi
    else
        echo "Error: Image generation failed (exit code: $gen_exit_code)" >&2
        echo "Output: ${image_url:0:200}" >&2
    fi
    
    echo "Error: Failed to generate badge image" >&2
    return 1
}

# Function to create thumbnails
create_thumbnails() {
    local source_image="$1"
    local badge_id="$2"
    
    if [[ ! -f "$source_image" ]]; then
        echo "Error: Source image not found: $source_image" >&2
        return 1
    fi
    
    echo "Creating thumbnails..." >&2
    
    # Check if ImageMagick is available
    if ! command -v convert &> /dev/null; then
        echo "Warning: ImageMagick not found, cannot create thumbnails" >&2
        return 1
    fi
    
    # Create 256x256 thumbnail
    local thumb_256="$BADGE_TMP_DIR/${badge_id}_256x256.png"
    convert "$source_image" -resize 256x256^ -gravity center -extent 256x256 "$thumb_256" 2>/dev/null
    
    # Create 64x64 thumbnail
    local thumb_64="$BADGE_TMP_DIR/${badge_id}_64x64.png"
    convert "$source_image" -resize 64x64^ -gravity center -extent 64x64 "$thumb_64" 2>/dev/null
    
    if [[ -f "$thumb_256" && -f "$thumb_64" ]]; then
        echo "Thumbnails created successfully" >&2
        return 0
    else
        echo "Warning: Failed to create some thumbnails" >&2
        return 1
    fi
}

# Function to upload to IPFS
upload_to_ipfs() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo "Error: File not found: $file_path" >&2
        return 1
    fi
    
    echo "Uploading to IPFS: $(basename "$file_path")" >&2
    
    # Use ipfs add command
    local ipfs_hash
    ipfs_hash=$(ipfs add -q "$file_path" 2>/dev/null)
    
    if [[ -n "$ipfs_hash" ]]; then
        echo "${myipfs}/ipfs/${ipfs_hash}"
        return 0
    else
        echo "Error: Failed to upload to IPFS" >&2
        return 1
    fi
}

# Main execution
main() {
    echo "🎨 Generating badge image for: $BADGE_ID" >&2
    echo "   Permit: $PERMIT_NAME" >&2
    [[ -n "$LEVEL" ]] && echo "   Level: $LEVEL ($LABEL)" >&2
    echo "" >&2
    
    # Step 1: Generate Stable Diffusion prompt
    local sd_prompt
    sd_prompt=$(generate_sd_prompt "$BADGE_ID" "$PERMIT_NAME" "$PERMIT_DESCRIPTION" "$LEVEL" "$LABEL")
    
    if [[ -z "$sd_prompt" ]]; then
        echo "Error: Failed to generate Stable Diffusion prompt" >&2
        exit 1
    fi
    
    echo "Generated prompt: ${sd_prompt:0:100}..." >&2
    echo "" >&2
    
    # Step 2: Generate main badge image (1024x1024)
    local main_image
    main_image=$(generate_badge_image "$BADGE_ID" "$sd_prompt")
    
    if [[ -z "$main_image" || ! -f "$main_image" ]]; then
        echo "Error: Failed to generate badge image" >&2
        # Return error JSON
        echo '{"success": false, "error": "Failed to generate badge image"}' >&2
        exit 1
    fi
    
    # Verify image is valid
    if ! file "$main_image" | grep -q "image"; then
        echo "Error: Generated file is not a valid image" >&2
        echo '{"success": false, "error": "Generated file is not a valid image"}' >&2
        exit 1
    fi
    
    echo "Main image generated: $main_image ($(du -h "$main_image" | cut -f1))" >&2
    
    # Step 3: Create thumbnails
    create_thumbnails "$main_image" "$BADGE_ID"
    
    # Step 4: Upload all images to IPFS
    local badge_image_url=""
    local badge_thumb_256=""
    local badge_thumb_64=""
    
    # Upload main image
    badge_image_url=$(upload_to_ipfs "$main_image")
    if [[ -z "$badge_image_url" ]]; then
        echo "Error: Failed to upload main image to IPFS" >&2
        exit 1
    fi
    
    # Upload 256x256 thumbnail
    local thumb_256_file="$BADGE_TMP_DIR/${BADGE_ID}_256x256.png"
    if [[ -f "$thumb_256_file" ]]; then
        badge_thumb_256=$(upload_to_ipfs "$thumb_256_file")
    fi
    
    # Upload 64x64 thumbnail
    local thumb_64_file="$BADGE_TMP_DIR/${BADGE_ID}_64x64.png"
    if [[ -f "$thumb_64_file" ]]; then
        badge_thumb_64=$(upload_to_ipfs "$thumb_64_file")
    fi
    
    # Step 5: Return JSON with URLs
    local result_json=$(jq -n \
        --arg badge_id "$BADGE_ID" \
        --arg image_url "$badge_image_url" \
        --arg thumb_256 "${badge_thumb_256:-$badge_image_url}" \
        --arg thumb_64 "${badge_thumb_64:-$badge_image_url}" \
        '{
            "badge_id": $badge_id,
            "badge_image_url": $image_url,
            "badge_thumb_256": $thumb_256,
            "badge_thumb_64": $thumb_64,
            "success": true
        }')
    
    echo "$result_json"
    
    # Cleanup temporary files (keep for debugging, remove after 1 hour)
    (sleep 3600 && rm -f "$main_image" "$thumb_256_file" "$thumb_64_file" 2>/dev/null) &
    
    return 0
}

# Run main function
main "$@"

