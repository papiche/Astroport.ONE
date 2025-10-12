#!/bin/bash
###################################################################
# test_cookie.sh - Teste les cookies YouTube des comptes MULTIPASS
#
# Usage: ./test_cookie.sh [email]
#
# Si aucun email n'est fourni, affiche la liste des comptes disponibles
###################################################################

NOSTR_DIR="$HOME/.zen/game/nostr"
TEST_VIDEO="https://www.youtube.com/watch?v=uWNPWDSsiiI"  # Video test courte
RESULTS_DIR="$HOME/.zen/tmp/cookie_tests"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🍪 TESTEUR DE COOKIES YOUTUBE - MULTIPASS"
echo "=========================================="
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function to list available accounts
list_accounts() {
    echo "📋 Comptes MULTIPASS disponibles:"
    echo ""
    
    local count=0
    for account_dir in "$NOSTR_DIR"/*@*; do
        if [[ -d "$account_dir" ]]; then
            local email=$(basename "$account_dir")
            local cookie_file="$account_dir/.cookie.txt"
            
            count=$((count + 1))
            
            if [[ -f "$cookie_file" ]]; then
                local cookie_age=$(($(date +%s) - $(stat -c %Y "$cookie_file" 2>/dev/null || echo 0)))
                local days_old=$((cookie_age / 86400))
                local hours_old=$(((cookie_age % 86400) / 3600))
                
                echo -e "${GREEN}✓${NC} [$count] $email"
                echo "      Cookie: Présent (âge: ${days_old}j ${hours_old}h)"
                echo "      Fichier: $cookie_file"
            else
                echo -e "${RED}✗${NC} [$count] $email"
                echo "      Cookie: Absent"
            fi
            echo ""
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "❌ Aucun compte MULTIPASS trouvé dans $NOSTR_DIR"
        return 1
    fi
    
    return 0
}

# Function to test cookie with yt-dlp metadata extraction
test_metadata_extraction() {
    local cookie_file="$1"
    local email="$2"
    
    echo ""
    echo "🔍 TEST 1: Extraction de métadonnées"
    echo "======================================"
    
    local output
    output=$(yt-dlp --cookies "$cookie_file" --print '%(id)s&%(title)s&%(duration)s&%(uploader)s' "$TEST_VIDEO" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 && -n "$output" ]]; then
        local video_id=$(echo "$output" | cut -d '&' -f 1)
        local title=$(echo "$output" | cut -d '&' -f 2)
        
        echo -e "${GREEN}✅ SUCCÈS${NC} - Métadonnées extraites"
        echo "   Video ID: $video_id"
        echo "   Titre: $title"
        return 0
    else
        echo -e "${RED}❌ ÉCHEC${NC} - Impossible d'extraire les métadonnées"
        
        # Check for specific errors
        if echo "$output" | grep -q "cookies are no longer valid"; then
            echo -e "   ${YELLOW}⚠️  Cookies expirés/rotés${NC}"
            echo "   YouTube a invalidé ces cookies (rotation de sécurité)"
        elif echo "$output" | grep -q "Sign in to confirm you're not a bot"; then
            echo -e "   ${YELLOW}⚠️  Détection de bot${NC}"
            echo "   YouTube demande une vérification humaine"
        elif echo "$output" | grep -q "Video unavailable"; then
            echo -e "   ${YELLOW}⚠️  Vidéo indisponible${NC}"
            echo "   (Les cookies peuvent être valides)"
        fi
        
        return 1
    fi
}

# Function to test cookie file structure
test_cookie_structure() {
    local cookie_file="$1"
    
    echo ""
    echo "📋 TEST 2: Structure du fichier cookies"
    echo "========================================"
    
    # Check Netscape format
    if grep -q "^# Netscape HTTP Cookie File" "$cookie_file"; then
        echo -e "${GREEN}✅${NC} Format Netscape détecté"
    else
        echo -e "${YELLOW}⚠️${NC}  En-tête Netscape manquant"
    fi
    
    # Count YouTube cookies
    local yt_cookies=$(grep -c "^[^#].*youtube.com" "$cookie_file" 2>/dev/null || echo 0)
    echo "   Cookies YouTube: $yt_cookies"
    
    # Check for critical cookies
    echo ""
    echo "   Cookies critiques:"
    local critical_found=0
    local critical_total=0
    
    for cookie_name in SAPISID APISID HSID SSID SID LOGIN_INFO VISITOR_INFO1_LIVE; do
        critical_total=$((critical_total + 1))
        if grep -q " $cookie_name " "$cookie_file"; then
            echo -e "   ${GREEN}✓${NC} $cookie_name"
            critical_found=$((critical_found + 1))
        else
            echo -e "   ${RED}✗${NC} $cookie_name"
        fi
    done
    
    echo ""
    echo "   Score: $critical_found/$critical_total cookies critiques présents"
    
    if [[ $critical_found -ge 4 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to test actual download (short video)
test_download() {
    local cookie_file="$1"
    local email="$2"
    
    echo ""
    echo "⬇️  TEST 3: Téléchargement réel (5 secondes)"
    echo "============================================"
    
    local temp_dir=$(mktemp -d)
    
    echo "   Dossier temporaire: $temp_dir"
    echo "   Tentative de téléchargement..."
    
    local output
    output=$(timeout 30 yt-dlp --cookies "$cookie_file" \
        -f "worst" \
        --max-filesize 1M \
        -o "$temp_dir/test.%(ext)s" \
        "$TEST_VIDEO" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        local downloaded_file=$(ls "$temp_dir"/test.* 2>/dev/null | head -1)
        if [[ -f "$downloaded_file" ]]; then
            local file_size=$(stat -c %s "$downloaded_file")
            echo -e "${GREEN}✅ SUCCÈS${NC} - Téléchargement réussi"
            echo "   Fichier: $(basename "$downloaded_file")"
            echo "   Taille: $((file_size / 1024)) KB"
            rm -rf "$temp_dir"
            return 0
        fi
    fi
    
    echo -e "${RED}❌ ÉCHEC${NC} - Téléchargement impossible"
    
    # Show relevant errors
    echo "$output" | grep -E "(ERROR|WARNING)" | head -5 | while read line; do
        echo "   $line"
    done
    
    rm -rf "$temp_dir"
    return 1
}

# Function to test browser cookie extraction (fallback)
test_browser_fallback() {
    local email="$1"
    
    echo ""
    echo "🌐 TEST 4: Fallback navigateur"
    echo "=============================="
    
    # Detect default browser
    local browser_pref=$(xdg-settings get default-web-browser 2>/dev/null | cut -d'.' -f1 | tr 'A-Z' 'a-z')
    
    if [[ -z "$browser_pref" ]]; then
        echo "   ℹ️  Navigateur par défaut non détecté"
        return 1
    fi
    
    echo "   Navigateur détecté: $browser_pref"
    
    local browser_cookies=""
    case "$browser_pref" in
        chromium|chrome) browser_cookies="--cookies-from-browser chrome" ;;
        firefox) browser_cookies="--cookies-from-browser firefox" ;;
        brave) browser_cookies="--cookies-from-browser brave" ;;
        edge) browser_cookies="--cookies-from-browser edge" ;;
        *) 
            echo "   ⚠️  Navigateur non supporté pour extraction automatique"
            return 1
            ;;
    esac
    
    echo "   Test d'extraction depuis le navigateur..."
    
    local output
    output=$(timeout 10 yt-dlp $browser_cookies --print '%(id)s' "$TEST_VIDEO" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 && -n "$output" ]]; then
        echo -e "${GREEN}✅${NC} Cookies du navigateur fonctionnels"
        echo "   ℹ️  Vous pouvez utiliser: yt-dlp $browser_cookies [URL]"
        return 0
    else
        echo -e "${RED}✗${NC} Cookies du navigateur non disponibles"
        return 1
    fi
}

# Function to generate detailed report
generate_report() {
    local email="$1"
    local cookie_file="$2"
    local test1_result="$3"
    local test2_result="$4"
    local test3_result="$5"
    local test4_result="$6"
    
    local report_file="$RESULTS_DIR/report_${email//[@.]/_}_${TIMESTAMP}.txt"
    
    cat > "$report_file" << EOF
====================================================
RAPPORT DE TEST DES COOKIES YOUTUBE
====================================================

Date: $(date '+%Y-%m-%d %H:%M:%S')
Compte: $email
Fichier: $cookie_file

----------------------------------------------------
RÉSULTATS DES TESTS
----------------------------------------------------

TEST 1 - Extraction métadonnées: $test1_result
TEST 2 - Structure du fichier:   $test2_result
TEST 3 - Téléchargement réel:    $test3_result
TEST 4 - Fallback navigateur:    $test4_result

----------------------------------------------------
SCORE GLOBAL
----------------------------------------------------
EOF

    local score=0
    [[ "$test1_result" == "PASS" ]] && score=$((score + 1))
    [[ "$test2_result" == "PASS" ]] && score=$((score + 1))
    [[ "$test3_result" == "PASS" ]] && score=$((score + 1))
    
    echo "Tests réussis: $score/3" >> "$report_file"
    echo "" >> "$report_file"
    
    if [[ $score -eq 3 ]]; then
        echo "✅ EXCELLENT - Les cookies sont pleinement fonctionnels" >> "$report_file"
    elif [[ $score -eq 2 ]]; then
        echo "⚠️  BON - Les cookies fonctionnent partiellement" >> "$report_file"
    elif [[ $score -eq 1 ]]; then
        echo "⚠️  MOYEN - Les cookies ont des limitations" >> "$report_file"
    else
        echo "❌ CRITIQUE - Les cookies ne fonctionnent pas" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "----------------------------------------------------" >> "$report_file"
    echo "RECOMMANDATIONS" >> "$report_file"
    echo "----------------------------------------------------" >> "$report_file"
    
    if [[ $score -lt 2 ]]; then
        cat >> "$report_file" << EOF

1. Exportez de nouveaux cookies depuis votre navigateur
   Guide: https://ipfs.copylaradio.com/ipns/copylaradio.com/cookie.html

2. Assurez-vous d'être connecté à YouTube dans le navigateur

3. Utilisez l'extension "Get cookies.txt LOCALLY"

4. Uploadez le fichier via: https://u.copylaradio.com/astro

EOF
    else
        echo "Les cookies sont fonctionnels. Aucune action requise." >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

====================================================
Rapport complet: $report_file
====================================================
EOF
    
    echo "$report_file"
}

# Main test function
test_account() {
    local email="$1"
    local account_dir="$NOSTR_DIR/$email"
    local cookie_file="$account_dir/.cookie.txt"
    
    echo ""
    echo "🧪 TESTS POUR: $email"
    echo "=========================================="
    
    # Check if account exists
    if [[ ! -d "$account_dir" ]]; then
        echo -e "${RED}❌ Compte non trouvé: $email${NC}"
        echo "   Répertoire: $account_dir"
        return 1
    fi
    
    # Check if cookie file exists
    if [[ ! -f "$cookie_file" ]]; then
        echo -e "${RED}❌ Fichier cookie non trouvé${NC}"
        echo "   Fichier attendu: $cookie_file"
        echo ""
        echo "💡 Pour ajouter des cookies:"
        echo "   1. Exportez les cookies depuis votre navigateur"
        echo "   2. Uploadez via https://u.copylaradio.com/astro"
        return 1
    fi
    
    # Show cookie info
    local cookie_size=$(stat -c %s "$cookie_file")
    local cookie_age=$(($(date +%s) - $(stat -c %Y "$cookie_file")))
    local days_old=$((cookie_age / 86400))
    local hours_old=$(((cookie_age % 86400) / 3600))
    
    echo ""
    echo "📄 Informations du fichier:"
    echo "   Chemin: $cookie_file"
    echo "   Taille: $cookie_size octets"
    echo "   Âge: ${days_old} jours ${hours_old} heures"
    
    # Run tests
    local test1_result="FAIL"
    local test2_result="FAIL"
    local test3_result="FAIL"
    local test4_result="FAIL"
    
    if test_metadata_extraction "$cookie_file" "$email"; then
        test1_result="PASS"
    fi
    
    if test_cookie_structure "$cookie_file"; then
        test2_result="PASS"
    fi
    
    if test_download "$cookie_file" "$email"; then
        test3_result="PASS"
    fi
    
    if test_browser_fallback "$email"; then
        test4_result="PASS"
    fi
    
    # Generate report
    echo ""
    echo "📊 GÉNÉRATION DU RAPPORT"
    echo "========================"
    
    local report_file=$(generate_report "$email" "$cookie_file" "$test1_result" "$test2_result" "$test3_result" "$test4_result")
    
    echo ""
    cat "$report_file"
    
    echo ""
    echo -e "${BLUE}📁 Rapport sauvegardé: $report_file${NC}"
}

# Main script logic
if [[ $# -eq 0 ]]; then
    # No argument provided, list accounts and prompt for selection
    if ! list_accounts; then
        exit 1
    fi
    
    echo "💡 Usage:"
    echo "   $0 <email>          # Tester un compte spécifique"
    echo "   $0 --all            # Tester tous les comptes"
    echo ""
    
    # Prompt for selection
    read -p "Entrez l'email du compte à tester (ou 'q' pour quitter): " selected_email
    
    if [[ "$selected_email" == "q" || -z "$selected_email" ]]; then
        echo "Annulé."
        exit 0
    fi
    
    test_account "$selected_email"
    
elif [[ "$1" == "--all" ]]; then
    # Test all accounts
    echo "🧪 TEST DE TOUS LES COMPTES MULTIPASS"
    echo "======================================"
    echo ""
    
    for account_dir in "$NOSTR_DIR"/*@*; do
        if [[ -d "$account_dir" ]]; then
            local email=$(basename "$account_dir")
            test_account "$email"
            echo ""
            echo "=================================================="
            echo ""
        fi
    done
    
    echo "✅ Tests terminés pour tous les comptes"
    echo "📁 Rapports dans: $RESULTS_DIR"
    
elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [options] [email]"
    echo ""
    echo "Options:"
    echo "  <email>     Tester un compte MULTIPASS spécifique"
    echo "  --all       Tester tous les comptes MULTIPASS"
    echo "  --help      Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0                          # Mode interactif"
    echo "  $0 user@example.com         # Tester un compte"
    echo "  $0 --all                    # Tester tous les comptes"
    echo ""
    echo "Les rapports sont sauvegardés dans: $RESULTS_DIR"
    
else
    # Test specific account
    test_account "$1"
fi

exit 0

