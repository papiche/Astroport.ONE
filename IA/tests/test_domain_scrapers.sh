#!/bin/bash
################################################################################
# test_domain_scrapers.sh - Test script for domain-based scraper system
# Usage: bash test_domain_scrapers.sh [player_email]
################################################################################

PLAYER="${1:-$CAPTAINEMAIL}"
echo "🧪 Testing domain-based scraper system for: $PLAYER"
echo ""

# Get script directory
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
PLAYER_DIR="$HOME/.zen/game/nostr/${PLAYER}"

echo "📁 Player directory: $PLAYER_DIR"
echo ""

# Test 1: Check if player directory exists
echo "Test 1: Check player directory"
if [[ -d "$PLAYER_DIR" ]]; then
    echo "✅ Player directory exists"
else
    echo "⚠️  Player directory does not exist (will be created in real scenario)"
fi
echo ""

# Test 2: List existing cookie files
echo "Test 2: List cookie files"
COOKIE_FILES=($(find "$PLAYER_DIR" -maxdepth 1 -type f -name ".*.cookie" 2>/dev/null))
if [[ ${#COOKIE_FILES[@]} -gt 0 ]]; then
    echo "✅ Found ${#COOKIE_FILES[@]} cookie file(s):"
    for COOKIE_FILE in "${COOKIE_FILES[@]}"; do
        BASENAME=$(basename "$COOKIE_FILE")
        echo "   - $BASENAME"
    done
else
    echo "⚠️  No cookie files found"
    echo "   Expected format: .DOMAIN.cookie (e.g., .youtube.com.cookie)"
fi
echo ""

# Test 3: Check scraper scripts
echo "Test 3: Check available scraper scripts"
SCRAPERS=($(find "${MY_PATH}" -maxdepth 1 -type f -name "*.sh" | grep -E "\.[a-z]+\.[a-z]+\.sh$|^[a-z]+\.[a-z]+\.sh$" 2>/dev/null))
if [[ ${#SCRAPERS[@]} -gt 0 ]]; then
    echo "✅ Found ${#SCRAPERS[@]} domain scraper(s):"
    for SCRAPER in "${SCRAPERS[@]}"; do
        BASENAME=$(basename "$SCRAPER")
        if [[ -x "$SCRAPER" ]]; then
            echo "   ✅ $BASENAME (executable)"
        else
            echo "   ⚠️  $BASENAME (NOT executable - run: chmod +x $SCRAPER)"
        fi
    done
else
    echo "⚠️  No domain scrapers found"
fi
echo ""

# Test 4: Match cookies with scrapers
echo "Test 4: Match cookies with available scrapers"
if [[ ${#COOKIE_FILES[@]} -gt 0 ]]; then
    for COOKIE_FILE in "${COOKIE_FILES[@]}"; do
        COOKIE_BASENAME=$(basename "$COOKIE_FILE")
        DOMAIN="${COOKIE_BASENAME#.}"
        DOMAIN="${DOMAIN%.cookie}"
        
        SCRAPER_PATH="${MY_PATH}/${DOMAIN}.sh"
        
        echo "   🍪 Cookie: $COOKIE_BASENAME"
        echo "      → Domain: $DOMAIN"
        
        if [[ -f "$SCRAPER_PATH" ]]; then
            if [[ -x "$SCRAPER_PATH" ]]; then
                echo "      → ✅ Scraper found: ${DOMAIN}.sh (ready to execute)"
            else
                echo "      → ⚠️  Scraper found but not executable: ${DOMAIN}.sh"
            fi
        else
            echo "      → ❌ No scraper found (would send notification email)"
        fi
        echo ""
    done
else
    echo "⚠️  No cookies to test"
fi

# Test 5: Check Python backend scripts
echo "Test 5: Check Python backend scripts"
PYTHON_SCRAPERS=($(find "${MY_PATH}" -maxdepth 1 -type f -name "scraper_*.py" 2>/dev/null))
if [[ ${#PYTHON_SCRAPERS[@]} -gt 0 ]]; then
    echo "✅ Found ${#PYTHON_SCRAPERS[@]} Python scraper(s):"
    for SCRAPER in "${PYTHON_SCRAPERS[@]}"; do
        BASENAME=$(basename "$SCRAPER")
        if [[ -x "$SCRAPER" ]]; then
            echo "   ✅ $BASENAME (executable)"
        else
            echo "   ⚠️  $BASENAME (NOT executable - recommended: chmod +x $SCRAPER)"
        fi
    done
else
    echo "⚠️  No Python backend scrapers found"
fi
echo ""

# Test 6: Check documentation
echo "Test 6: Check documentation"
if [[ -f "${MY_PATH}/DOMAIN_SCRAPERS.md" ]]; then
    echo "✅ DOMAIN_SCRAPERS.md exists"
else
    echo "⚠️  DOMAIN_SCRAPERS.md not found"
fi

if [[ -f "${MY_PATH}/COOKIE_SYSTEM.md" ]]; then
    echo "✅ COOKIE_SYSTEM.md exists"
else
    echo "⚠️  COOKIE_SYSTEM.md not found"
fi
echo ""

# Summary
echo "================================"
echo "📊 Summary"
echo "================================"
echo "Cookies found: ${#COOKIE_FILES[@]}"
echo "Scrapers found: ${#SCRAPERS[@]}"
echo "Python backends: ${#PYTHON_SCRAPERS[@]}"
echo ""
echo "✅ Test complete!"
echo ""
echo "📚 Next steps:"
echo "   1. Upload cookies via: https://u.copylaradio.com/cookie"
echo "   2. Create scraper scripts: DOMAIN.sh in Astroport.ONE/IA/"
echo "   3. Make executable: chmod +x DOMAIN.sh"
echo "   4. Read documentation: DOMAIN_SCRAPERS.md"

