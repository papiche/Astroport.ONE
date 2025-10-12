#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# MULTIPASS.print.sh - Print MULTIPASS Authentication Card
#
# Prints a MULTIPASS card with two essential QR codes:
# 1. uSPOT/scan QR - Small, top-left for quick mobile access
# 2. SSSS QR - Large, full-width for terminal authentication
#
# This card allows the user to authenticate on any UPlanet terminal
# without needing browser storage, using mobile phone scanning.
#
# Usage: MULTIPASS.print.sh [--force] <EMAIL>
#        --force : Regenerate card even if it already exists
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "$MY_PATH/my.sh"

# Parse arguments
FORCE=false
EMAIL=""

for arg in "$@"; do
    if [[ "$arg" == "--force" ]]; then
        FORCE=true
    elif [[ -z "$EMAIL" ]]; then
        EMAIL="$arg"
    fi
done

if [[ -z "$EMAIL" ]]; then
    echo "Usage: $0 [--force] <EMAIL>"
    echo "Example: $0 user@example.com"
    echo "         $0 --force user@example.com"
    exit 1
fi

# Validate email format
if [[ ! $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "❌ Invalid email format: $EMAIL"
    exit 1
fi

# Check if MULTIPASS directory exists
MULTIPASS_DIR="${HOME}/.zen/game/nostr/${EMAIL}"
if [[ ! -d "$MULTIPASS_DIR" ]]; then
    echo "❌ MULTIPASS not found for: $EMAIL"
    echo "   Directory: $MULTIPASS_DIR"
    exit 1
fi

# Check if required QR codes exist
USPOT_QR="${MULTIPASS_DIR}/uSPOT.QR.png"
SSSS_QR="${MULTIPASS_DIR}/._SSSSQR.png"

if [[ ! -f "$USPOT_QR" ]]; then
    echo "❌ uSPOT QR code not found: $USPOT_QR"
    exit 1
fi

if [[ ! -f "$SSSS_QR" ]]; then
    echo "❌ SSSS QR code not found: $SSSS_QR"
    exit 1
fi

# Get user info
YOUSER=$(${MY_PATH}/clyuseryomail.sh ${EMAIL})
G1PUBNOSTR=$(cat ${MULTIPASS_DIR}/G1PUBNOSTR 2>/dev/null || echo "")
NPUBLIC=$(cat ${MULTIPASS_DIR}/NPUB 2>/dev/null || echo "")

# Final output location
FINAL_OUTPUT="${HOME}/.zen/game/nostr/${EMAIL}/.MULTIPASS.CARD.png"

# Check if card already exists
if [[ -f "$FINAL_OUTPUT" && "$FORCE" == false ]]; then
    echo "✅ MULTIPASS card already exists: $FINAL_OUTPUT"
    echo "   Use --force to regenerate"
    
    # Check if printer is connected for printing existing card
    LP=$(ls /dev/usb/lp* 2>/dev/null | head -n 1)
    if [[ -n "$LP" ]]; then
        echo "🖨️  Printing existing MULTIPASS card..."
        # Jump to print section
        SKIP_GENERATION=true
    else
        echo "ℹ️  No printer detected. Card image available at: $FINAL_OUTPUT"
        exit 0
    fi
else
    SKIP_GENERATION=false
fi

echo "🎫 Preparing MULTIPASS card for: $EMAIL"
echo "   User: $YOUSER"

# Create temporary directory
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
TMP_DIR="${HOME}/.zen/tmp/${MOATS}"
mkdir -p "$TMP_DIR"

# Check if printer is connected
LP=$(ls /dev/usb/lp* 2>/dev/null | head -n 1)

if [[ -z "$LP" ]]; then
    echo "⚠️  No Brother QL printer detected"
    echo "   Generating card image only (no print)"
fi

################################################################################
# Create composite image with both QR codes
################################################################################

if [[ "$SKIP_GENERATION" == false ]]; then
    echo "🎨 Generating MULTIPASS card layout..."
    
    # New layout: uSPOT small top-left, SSSS large bottom full-width
    # Brother QL-700: 62mm label, optimal canvas 696x1000 pixels for vertical layout
    
    # Resize QR codes
    convert "$USPOT_QR" -resize 180x180 "$TMP_DIR/uspot_resized.png"
    convert "$SSSS_QR" -resize 650x650 "$TMP_DIR/ssss_resized.png"
    
    # Create base canvas (696x1000 for Brother QL-700 continuous)
    convert -size 696x1000 xc:white "$TMP_DIR/base.png"
    
    # Add header section with border
    convert "$TMP_DIR/base.png" \
        -fill "#667eea" -draw "rectangle 0,0 696,200" \
        -fill white -draw "rectangle 5,5 691,195" \
        "$TMP_DIR/with_header.png"
    
    # Composite uSPOT QR top-left inside header
    composite -compose Over -gravity NorthWest -geometry +10+10 \
        "$TMP_DIR/uspot_resized.png" "$TMP_DIR/with_header.png" "$TMP_DIR/with_uspot.png"
    
    # Add text labels to the right of uSPOT QR
    G1SHORT="${G1PUBNOSTR:0:8}"
    convert "$TMP_DIR/with_uspot.png" \
        -gravity NorthWest -pointsize 28 -fill "#667eea" -font "DejaVu-Sans-Bold" -annotate +200+15 "MULTIPASS" \
        -gravity NorthWest -pointsize 18 -fill black -annotate +200+55 "$EMAIL" \
        -gravity NorthWest -pointsize 16 -fill "#667eea" -annotate +200+85 "$YOUSER" \
        -gravity NorthWest -pointsize 14 -fill "#888888" -annotate +200+110 "G1: $G1SHORT" \
        -gravity NorthWest -pointsize 12 -fill "#666666" -annotate +200+135 "uSPOT Scan Authentication" \
        "$TMP_DIR/with_text.png"
    
    # Add separator line
    convert "$TMP_DIR/with_text.png" \
        -fill "#cccccc" -draw "line 20,210 676,210" \
        "$TMP_DIR/with_separator.png"
    
    # Add SSSS label above QR
    convert "$TMP_DIR/with_separator.png" \
        -gravity North -pointsize 22 -fill black -font "DejaVu-Sans-Bold" -annotate +0+225 "SSSS Authentication Key" \
        -gravity North -pointsize 14 -fill "#666666" -annotate +0+255 "Scan on any UPlanet terminal" \
        "$TMP_DIR/with_ssss_label.png"
    
    # Composite large SSSS QR at bottom center
    composite -compose Over -gravity South -geometry +0+15 \
        "$TMP_DIR/ssss_resized.png" "$TMP_DIR/with_ssss_label.png" "$TMP_DIR/multipass_card.png"
    
    # Save to final location
    cp "$TMP_DIR/multipass_card.png" "$FINAL_OUTPUT"
    
    echo "✅ MULTIPASS card created: $FINAL_OUTPUT"
else
    echo "♻️  Using existing MULTIPASS card"
fi

# Display if GUI available
if [[ "$XDG_SESSION_TYPE" == "x11" || "$XDG_SESSION_TYPE" == "wayland" ]]; then
    xdg-open "$FINAL_OUTPUT" 2>/dev/null &
fi

################################################################################
# Print if Brother QL printer is available
################################################################################

if [[ -n "$LP" ]]; then
    echo "🖨️  Printing MULTIPASS card on Brother QL-700..."
    
    # Check if brother_ql tools are available
    if ! command -v brother_ql_create &> /dev/null; then
        echo "⚠️  brother_ql_create not found. Install with: pip install brother_ql"
        echo "   Card image saved but not printed."
    else
        # Create temporary directory if not exists
        [[ ! -d "$TMP_DIR" ]] && TMP_DIR="${HOME}/.zen/tmp/$(date -u +"%Y%m%d%H%M%S%4N")" && mkdir -p "$TMP_DIR"
        
        # Create print file from final output
        brother_ql_create --model QL-700 --label-size 62 \
            "$FINAL_OUTPUT" > "$TMP_DIR/multipass.bin" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            # Print
            if command -v brother_ql_print &> /dev/null; then
                brother_ql_print "$TMP_DIR/multipass.bin" "$LP" 2>/dev/null
                
                if [[ $? -eq 0 ]]; then
                    echo "✅ MULTIPASS card printed successfully!"
                else
                    echo "❌ Print failed. Check printer connection."
                fi
            else
                # Try with sudo
                sudo brother_ql_print "$TMP_DIR/multipass.bin" "$LP" 2>/dev/null
                
                if [[ $? -eq 0 ]]; then
                    echo "✅ MULTIPASS card printed successfully!"
                else
                    echo "❌ Print failed. Check printer connection and permissions."
                fi
            fi
        else
            echo "❌ Failed to create print file."
        fi
    fi
else
    echo "ℹ️  To print later, connect Brother QL printer and run:"
    echo "   $0 $EMAIL"
fi

################################################################################
# Cleanup temporary files (keep final output)
################################################################################
[[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"

echo ""
echo "📋 MULTIPASS Card Summary:"
echo "   Email: $EMAIL"
echo "   User: $YOUSER"
echo "   G1 Wallet: $G1PUBNOSTR"
echo "   Card: $FINAL_OUTPUT"
echo ""
echo "💡 Usage:"
echo "   • Scan small uSPOT QR with phone to access ${uSPOT}/scan"
echo "   • Scan large SSSS QR on any UPlanet terminal for authentication"
echo "   • Keep this card secure - it's your identity key!"
echo ""
echo "🔄 To regenerate: $0 --force $EMAIL"
echo ""

exit 0

