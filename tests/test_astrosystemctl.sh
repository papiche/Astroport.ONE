#!/bin/bash
###############################################################################
# tests/test_astrosystemctl.sh
# Batterie de tests pour tools/astrosystemctl.sh
#
# Usage : ./tests/test_astrosystemctl.sh [groupe]
#   groupes : pure env private modules check install commands errors
#   (sans argument : tous les groupes)
#
# Architecture :
#   - Tests en-process  : fonctions sourcées via ASTROSYSTEMCTL_TEST=1
#   - Tests subprocess  : appels à astrosystemctl local check / install / help
#   - Mocks PATH        : docker, pgrep, ss, systemctl dans $TEST_MOCK_BIN
###############################################################################

# Tests : set -u pour variables non liées, pas set -e (les assertions peuvent échouer)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASTRO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/test_common.sh"

###############################################################################
# SETUP / TEARDOWN
###############################################################################

TEST_WORKDIR="$(mktemp -d /tmp/test_astrosystemctl_XXXXXX)"
TEST_MOCK_BIN="$TEST_WORKDIR/bin"
TEST_FAKE_HOME="$TEST_WORKDIR/home"
TEST_FAKE_IPFSID="QmTestNode000000000000000000000000000TestID"

trap '_teardown_all' EXIT

_teardown_all() {
    rm -rf "$TEST_WORKDIR"
}

# ── Création de l'environnement factice ──────────────────────────────────────
_setup_fake_env() {
    mkdir -p "$TEST_MOCK_BIN"
    mkdir -p "$TEST_FAKE_HOME/.zen/tmp/$TEST_FAKE_IPFSID"
    mkdir -p "$TEST_FAKE_HOME/.zen/Astroport.ONE"
    mkdir -p "$TEST_FAKE_HOME/.zen/tunnels/enabled"
    mkdir -p "$TEST_FAKE_HOME/.zen/tmp/swarm"
    mkdir -p "$TEST_WORKDIR/IA"
    mkdir -p "$TEST_WORKDIR/install"

    # modules.list de test
    cat > "$TEST_WORKDIR/IA/modules.list" << 'EOF'
# Format : name|port|check|install_group|label
icecast|8111|auto|icecast|Icecast Live Broadcasting
dify|8010|docker:dify-api|ai-company|Dify AI Workflow
ollama|11434|pgrep:ollama|gpu-ai|Ollama LLM API
open-webui|8000|docker:open-webui|ai-company|Open WebUI Interface IA
qdrant|6333|docker:qdrant|ai-company|Qdrant VectorDB
comfyui|8188|systemctl:comfyui|gpu-ai|ComfyUI Image Generation
webtop-http|3000|dockerimg:linuxserver/webtop|webtop|Webtop KasmVNC HTTP
# commentaire ignoré
youtube-antibot|-|-|youtube-antibot|YouTube Anti-Bot
powerjoular|-|-|powerjoular|Power Consumption Monitor
EOF

    # Scripts install factices
    touch "$TEST_WORKDIR/install/install-ai-company.docker.sh"
    touch "$TEST_WORKDIR/install/install_gpu_ai.sh"
    touch "$TEST_WORKDIR/install/install_youtube_antibot.sh"
    touch "$TEST_WORKDIR/install/install_powerjoular.sh"
    touch "$TEST_WORKDIR/install/install_icecast.sh"
    touch "$TEST_WORKDIR/install/install_webtop.sh"
    chmod +x "$TEST_WORKDIR/install/"*.sh

    # .env factice
    echo 'DRAGON_PRIVATE_SERVICES=""' > "$TEST_FAKE_HOME/.zen/Astroport.ONE/.env"

    # Heartbox : Brain sans GPU (i5, 12 cœurs, 38Go, score 43)
    _write_heartbox_brain_nogpu

    # Mock binaires
    _setup_mock_bins
}

_write_heartbox_brain_nogpu() {
    cat > "$TEST_FAKE_HOME/.zen/tmp/$TEST_FAKE_IPFSID/heartbox_analysis.json" << EOF
{
  "capacities": {
    "power_score": 43,
    "available_space_gb": 500,
    "gpu": { "detected": false, "vram_gb": 0 },
    "provider_ready": true,
    "storage_ready": true
  },
  "system": {
    "cpu": { "cores": 12, "model": "Intel i5-1235U" },
    "memory": { "total_gb": 38, "used_gb": 16 }
  }
}
EOF
}

_write_heartbox_brain_gpu() {
    cat > "$TEST_FAKE_HOME/.zen/tmp/$TEST_FAKE_IPFSID/heartbox_analysis.json" << EOF
{
  "capacities": {
    "power_score": 82,
    "available_space_gb": 800,
    "gpu": { "detected": true, "vram_gb": 8 },
    "provider_ready": true,
    "storage_ready": true
  },
  "system": {
    "cpu": { "cores": 16, "model": "AMD Ryzen 9" },
    "memory": { "total_gb": 64, "used_gb": 20 }
  }
}
EOF
}

_write_heartbox_light() {
    cat > "$TEST_FAKE_HOME/.zen/tmp/$TEST_FAKE_IPFSID/heartbox_analysis.json" << EOF
{
  "capacities": {
    "power_score": 5,
    "available_space_gb": 20,
    "gpu": { "detected": false, "vram_gb": 0 },
    "provider_ready": false,
    "storage_ready": false
  },
  "system": {
    "cpu": { "cores": 4, "model": "Cortex-A72" },
    "memory": { "total_gb": 4, "used_gb": 2 }
  }
}
EOF
}

_setup_mock_bins() {
    # docker : simule qdrant et open-webui actifs
    cat > "$TEST_MOCK_BIN/docker" << 'MOCK'
#!/bin/bash
args="$*"
case "$args" in
    "ps"*)
        if [[ "$args" == *"{{.Names}}"* ]]; then
            echo "qdrant"; echo "open-webui"
        elif [[ "$args" == *"{{.Image}}"* ]]; then
            echo "qdrant/qdrant:latest"; echo "ghcr.io/open-webui/open-webui:main"
        else
            printf "%-20s %-30s %s\n" "qdrant" "qdrant/qdrant:latest" "Up 2 hours"
            printf "%-20s %-30s %s\n" "open-webui" "ghcr.io/open-webui/open-webui:main" "Up 1 hour"
        fi ;;
    "ps -a"*) ;;
    *) ;;
esac
exit 0
MOCK
    chmod +x "$TEST_MOCK_BIN/docker"

    # pgrep : ollama actif, rien d'autre
    cat > "$TEST_MOCK_BIN/pgrep" << 'MOCK'
#!/bin/bash
case "${1:-}" in
    ollama) exit 0 ;;
    *) exit 1 ;;
esac
MOCK
    chmod +x "$TEST_MOCK_BIN/pgrep"

    # ss : icecast (8111) et qdrant (6333) écoutent
    cat > "$TEST_MOCK_BIN/ss" << 'MOCK'
#!/bin/bash
echo "tcp   LISTEN 0  128  0.0.0.0:8111  0.0.0.0:*"
echo "tcp   LISTEN 0  128  0.0.0.0:6333  0.0.0.0:*"
MOCK
    chmod +x "$TEST_MOCK_BIN/ss"

    # systemctl : aucun service actif
    cat > "$TEST_MOCK_BIN/systemctl" << 'MOCK'
#!/bin/bash
case "${1:-}" in
    is-active) exit 1 ;;  # tout inactif
    list-unit-files) echo "" ;;
    *) exit 0 ;;
esac
MOCK
    chmod +x "$TEST_MOCK_BIN/systemctl"

    # ipfs : stub minimal
    cat > "$TEST_MOCK_BIN/ipfs" << 'MOCK'
#!/bin/bash
case "${1:-}" in
    p2p)   echo "" ;;
    swarm) echo "" ;;
    id)    echo '{"ID":"QmTest","Addresses":[]}' ;;
    *)     exit 0 ;;
esac
MOCK
    chmod +x "$TEST_MOCK_BIN/ipfs"
}

# ── Sourcing des fonctions (en-process) ──────────────────────────────────────
_SOURCED_ASTROSYSTEMCTL=0

_source_astrosystemctl() {
    [[ $_SOURCED_ASTROSYSTEMCTL -eq 1 ]] && return 0
    local orig_path="$PATH"
    export PATH="$TEST_MOCK_BIN:$PATH"
    export ASTROSYSTEMCTL_TEST=1
    export MY_PATH="$ASTRO_DIR/tools"
    export IPFSNODEID="$TEST_FAKE_IPFSID"
    export SWARM_DIR="$TEST_FAKE_HOME/.zen/tmp/swarm"
    export TUNNELS_ENABLED="$TEST_FAKE_HOME/.zen/tunnels/enabled"
    export TUNNEL_LOG="$TEST_FAKE_HOME/.zen/tmp/tunnel.log"
    # shellcheck source=/dev/null
    source "$ASTRO_DIR/tools/astrosystemctl.sh" 2>/dev/null
    export PATH="$orig_path"
    unset ASTROSYSTEMCTL_TEST
    _SOURCED_ASTROSYSTEMCTL=1
}

# ── Appel subprocess (commandes complètes) ────────────────────────────────────
_run_astrosystemctl() {
    PATH="$TEST_MOCK_BIN:$PATH" \
    HOME="$TEST_FAKE_HOME" \
    IPFSNODEID="$TEST_FAKE_IPFSID" \
    SWARM_DIR="$TEST_FAKE_HOME/.zen/tmp/swarm" \
    bash "$ASTRO_DIR/tools/astrosystemctl.sh" "$@" 2>/dev/null
}

###############################################################################
# GROUPE 1 : Fonctions pures
###############################################################################
run_tests_pure() {
    test_log_info "=== GROUPE 1 : Fonctions pures ==="

    _source_astrosystemctl

    # power_label — limites de tier
    assert_equal "🌿 Light"   "$(power_label 0)"  "power_label(0) = Light"
    assert_equal "🌿 Light"   "$(power_label 5)"  "power_label(5) = Light"
    assert_equal "🌿 Light"   "$(power_label 10)" "power_label(10) = Light (boundary)"
    assert_true  '[[ "$(power_label 11)" == *"Std"* ]]'  "power_label(11) = Standard (boundary)"
    assert_true  '[[ "$(power_label 40)" == *"Std"* ]]'  "power_label(40) = Standard (boundary)"
    assert_true  '[[ "$(power_label 41)" == *"Brain"* ]]' "power_label(41) = Brain (boundary)"
    assert_true  '[[ "$(power_label 100)" == *"Brain"* ]]' "power_label(100) = Brain"

    # _svc_to_hb_key — normalisation des noms
    assert_equal "open_webui"    "$(_svc_to_hb_key 'open-webui')"    "_svc_to_hb_key: tirets → underscores"
    assert_equal "dify"          "$(_svc_to_hb_key 'dify.ai')"       "_svc_to_hb_key: .ai supprimé"
    assert_equal "ollama"        "$(_svc_to_hb_key 'ollama')"        "_svc_to_hb_key: inchangé"
    assert_equal "nextcloud_aio" "$(_svc_to_hb_key 'nextcloud-aio')" "_svc_to_hb_key: nextcloud-aio"
    assert_equal "webtop_http"   "$(_svc_to_hb_key 'webtop-http')"   "_svc_to_hb_key: webtop-http"

    # get_service_category
    assert_true '[[ "$(get_service_category ollama)" == *"IA"* ]]'      "category: ollama = IA"
    assert_true '[[ "$(get_service_category comfyui)" == *"IA"* ]]'     "category: comfyui = IA"
    assert_true '[[ "$(get_service_category icecast)" == *"Audio"* ]]'  "category: icecast = Audio"
    assert_true '[[ "$(get_service_category ssh)" == *"Sys"* ]]'        "category: ssh = Sys"
    assert_true '[[ "$(get_service_category nextcloud)" == *"Sys"* ]]'  "category: nextcloud = Sys"
    assert_true '[[ "$(get_service_category xyz123)" == *"App"* ]]'     "category: inconnu = App"

    # _group_to_install_script
    local BASE="/astro"
    assert_true '[[ "$(_group_to_install_script gpu-ai $BASE)" == *"install_gpu_ai.sh"* ]]'              "_group: gpu-ai"
    assert_true '[[ "$(_group_to_install_script ai-company $BASE)" == *"install-ai-company.docker.sh"* ]]' "_group: ai-company"
    assert_true '[[ "$(_group_to_install_script youtube-antibot $BASE)" == *"install_youtube_antibot.sh"* ]]' "_group: youtube-antibot"
    assert_true '[[ "$(_group_to_install_script powerjoular $BASE)" == *"install_powerjoular.sh"* ]]'    "_group: powerjoular"
    assert_true '[[ "$(_group_to_install_script prometheus $BASE)" == *"install_prometheus.sh"* ]]'      "_group: prometheus"
    assert_true '[[ "$(_group_to_install_script leann $BASE)" == *"install_leann.sh"* ]]'               "_group: leann"
    assert_true '[[ "$(_group_to_install_script zelkova $BASE)" == *"install_zelkova.sh"* ]]'           "_group: zelkova"
    assert_equal "" "$(_group_to_install_script core $BASE)"    "_group: core → vide"
    assert_equal "" "$(_group_to_install_script - $BASE)"       "_group: - → vide"
    assert_true '[[ "$(_group_to_install_script mongroupe $BASE)" == *"install_mongroupe.sh"* ]]'       "_group: inconnu → pattern générique"
}

###############################################################################
# GROUPE 2 : Helpers environnement
###############################################################################
run_tests_env() {
    test_log_info "=== GROUPE 2 : Helpers environnement ==="

    _source_astrosystemctl

    # _modules_list_path — trouve le fichier réel du projet
    local found
    found="$(_modules_list_path)"
    assert_not_empty "$found" "_modules_list_path: fichier trouvé"
    assert_true '[[ -f "$(_modules_list_path)" ]]' "_modules_list_path: chemin valide"
    assert_true '[[ "$(_modules_list_path)" == *"modules.list"* ]]' "_modules_list_path: nom correct"

    # _modules_list_path — absent si ni MY_PATH ni HOME ne contiennent modules.list
    local orig_my_path="$MY_PATH"
    local orig_home_env="$HOME"
    MY_PATH="/tmp/chemin_inexistant_$$"
    HOME="$TEST_FAKE_HOME"  # fake home sans modules.list
    assert_equal "" "$(_modules_list_path)" "_modules_list_path: vide si absent"
    MY_PATH="$orig_my_path"
    HOME="$orig_home_env"

    # _ia_dir — trouve le répertoire IA/
    local ia
    ia="$(_ia_dir)"
    assert_not_empty "$ia" "_ia_dir: répertoire trouvé"
    assert_true '[[ -d "$(_ia_dir)" ]]' "_ia_dir: répertoire valide"

    # _find_me_sh — trouve .me.sh depuis nom service
    local ia_real
    ia_real="$(_ia_dir)"
    if [[ -d "$ia_real" ]]; then
        # Test avec un fichier qui existe sûrement (ollama.me.sh)
        if [[ -f "$ia_real/ollama.me.sh" ]]; then
            assert_not_empty "$(_find_me_sh "$ia_real" "ollama")" "_find_me_sh: ollama trouvé"
        fi
        # Test conversion tirets → underscores
        if [[ -f "$ia_real/open-webui.me.sh" ]]; then
            assert_not_empty "$(_find_me_sh "$ia_real" "open_webui")" "_find_me_sh: open_webui → open-webui.me.sh"
        fi
    fi
    # Service inexistant → vide
    assert_equal "" "$(_find_me_sh "/tmp" "service_qui_nexiste_pas_$$")" "_find_me_sh: inexistant → vide"
}

###############################################################################
# GROUPE 3 : Gestion services privés
###############################################################################
run_tests_private() {
    test_log_info "=== GROUPE 3 : Services privés (DRAGON_PRIVATE_SERVICES) ==="

    _source_astrosystemctl

    local orig_home="$HOME"
    export HOME="$TEST_FAKE_HOME"

    # _priv_list — liste vide
    echo 'DRAGON_PRIVATE_SERVICES=""' > "$TEST_FAKE_HOME/.zen/Astroport.ONE/.env"
    assert_equal "" "$(_priv_list)" "_priv_list: liste vide"

    # _priv_list — un service
    echo 'DRAGON_PRIVATE_SERVICES="ollama"' > "$TEST_FAKE_HOME/.zen/Astroport.ONE/.env"
    assert_equal "ollama" "$(_priv_list)" "_priv_list: un service"

    # _priv_list — plusieurs services
    echo 'DRAGON_PRIVATE_SERVICES="ollama qdrant"' > "$TEST_FAKE_HOME/.zen/Astroport.ONE/.env"
    assert_true '[[ "$(_priv_list)" == *"ollama"* ]]' "_priv_list: contient ollama"
    assert_true '[[ "$(_priv_list)" == *"qdrant"* ]]' "_priv_list: contient qdrant"

    # _is_private — service présent
    assert_true '_is_private "ollama"' "_is_private: ollama dans la liste"
    assert_true '_is_private "qdrant"' "_is_private: qdrant dans la liste"

    # _is_private — service absent
    assert_false '_is_private "dify"' "_is_private: dify pas dans la liste"
    assert_false '_is_private "comfyui"' "_is_private: comfyui pas dans la liste"

    # _is_private — pas de correspondance partielle (ollama ≠ ollama2)
    echo 'DRAGON_PRIVATE_SERVICES="ollama"' > "$TEST_FAKE_HOME/.zen/Astroport.ONE/.env"
    assert_false '_is_private "ollama2"' "_is_private: pas de match partiel (ollama2 ≠ ollama)"

    # _env_set_private add — ajoute un service
    echo 'DRAGON_PRIVATE_SERVICES=""' > "$TEST_FAKE_HOME/.zen/Astroport.ONE/.env"
    _env_set_private "comfyui" "add" >/dev/null 2>&1
    assert_true '_is_private "comfyui"' "_env_set_private add: comfyui ajouté"

    # _env_set_private add — idempotent (pas de doublon)
    _env_set_private "comfyui" "add" >/dev/null 2>&1
    local count
    count=$(grep -o "comfyui" "$TEST_FAKE_HOME/.zen/Astroport.ONE/.env" | wc -l)
    assert_equal "1" "$count" "_env_set_private add: pas de doublon"

    # _env_set_private remove — retire un service
    _env_set_private "comfyui" "remove" >/dev/null 2>&1
    assert_false '_is_private "comfyui"' "_env_set_private remove: comfyui retiré"

    export HOME="$orig_home"
    echo 'DRAGON_PRIVATE_SERVICES=""' > "$TEST_FAKE_HOME/.zen/Astroport.ONE/.env"
}

###############################################################################
# GROUPE 4 : Parsing modules.list
###############################################################################
run_tests_modules() {
    test_log_info "=== GROUPE 4 : Parsing IA/modules.list ==="

    local mlist="$TEST_WORKDIR/IA/modules.list"

    # Nombre de modules avec port défini (non -)
    local port_count
    port_count=$(awk -F'|' '!/^[[:space:]]*#/ && NF>=4 && $2 != "-" && $2 != "" && $1 != ""' "$mlist" | wc -l)
    assert_true '[[ "$port_count" -gt 0 ]]' "modules.list: entrées avec port > 0"

    # Nombre de modules sans port (outils système)
    local sys_count
    sys_count=$(awk -F'|' '!/^[[:space:]]*#/ && NF>=4 && $2 == "-" && $1 != ""' "$mlist" | wc -l)
    assert_true '[[ "$sys_count" -gt 0 ]]' "modules.list: entrées sans port (outils système) > 0"

    # Les commentaires sont ignorés
    local comment_count
    comment_count=$(awk -F'|' '/^[[:space:]]*#/' "$mlist" | wc -l)
    assert_true '[[ "$comment_count" -gt 0 ]]' "modules.list: commentaires présents"

    # Les modules attendus sont dans le fichier
    assert_true 'grep -q "^ollama|" "$mlist"'          "modules.list: ollama présent"
    assert_true 'grep -q "^dify|" "$mlist"'            "modules.list: dify présent"
    assert_true 'grep -q "^youtube-antibot|" "$mlist"' "modules.list: youtube-antibot présent"
    assert_true 'grep -q "^webtop-http|" "$mlist"'     "modules.list: webtop-http présent"

    # Format correct : chaque ligne non-commentée a au moins 5 champs
    local bad_lines
    bad_lines=$(awk -F'|' '!/^[[:space:]]*#/ && NF > 0 && NF < 5 && $1 != ""' "$mlist" | wc -l)
    assert_equal "0" "$bad_lines" "modules.list: toutes les lignes ont ≥5 champs"

    # Vérification du fichier RÉEL du projet
    local real_mlist
    real_mlist="$ASTRO_DIR/IA/modules.list"
    assert_true '[[ -f "$real_mlist" ]]' "IA/modules.list réel: existe dans le projet"

    local real_bad
    real_bad=$(awk -F'|' '!/^[[:space:]]*#/ && NF > 0 && NF < 5 && $1 != ""' "$real_mlist" | wc -l)
    assert_equal "0" "$real_bad" "IA/modules.list réel: format correct (≥5 champs par ligne)"
}

###############################################################################
# GROUPE 5 : _local_check — profils matériels
###############################################################################
run_tests_check() {
    test_log_info "=== GROUPE 5 : _local_check (conseiller matériel) ==="

    local orig_home="$HOME"
    local orig_path="$PATH"
    export HOME="$TEST_FAKE_HOME"
    export PATH="$TEST_MOCK_BIN:$PATH"

    _source_astrosystemctl

    # Remplacer _modules_list_path pour pointer vers le modules.list de test
    _modules_list_path() { echo "$TEST_WORKDIR/IA/modules.list"; }
    _group_to_install_script_orig="$(_group_to_install_script gpu-ai "$TEST_WORKDIR")"

    # ── Profil : Brain sans GPU ────────────────────────────────────────────
    _write_heartbox_brain_nogpu
    local out_brain_nogpu
    out_brain_nogpu="$(IPFSNODEID="$TEST_FAKE_IPFSID" _local_check 2>/dev/null)"

    assert_true '[[ "$out_brain_nogpu" == *"43"* ]]'           "check Brain noGPU: Power-Score 43"
    assert_true '[[ "$out_brain_nogpu" == *"Brain"* ]]'        "check Brain noGPU: tier Brain"
    assert_true '[[ "$out_brain_nogpu" == *"12"* ]]'           "check Brain noGPU: 12 cœurs CPU"
    assert_true '[[ "$out_brain_nogpu" == *"38"* ]]'           "check Brain noGPU: 38 Go RAM"
    assert_true '[[ "$out_brain_nogpu" == *"pas de GPU"* ]]'   "check Brain noGPU: GPU absent affiché"
    assert_true '[[ "$out_brain_nogpu" == *"GPU"*"requis"* ]]' "check Brain noGPU: comfyui signalé GPU requis"
    assert_true '[[ "$out_brain_nogpu" == *"petits modèles"* ]]' "check Brain noGPU: ollama recommandé CPU"
    assert_false 'echo "$out_brain_nogpu" | grep "ollama" | grep -q "GPU ≥6Go VRAM requis"' "check Brain noGPU: ollama pas bloqué"

    # ── Profil : Brain avec GPU ────────────────────────────────────────────
    _write_heartbox_brain_gpu
    local out_brain_gpu
    out_brain_gpu="$(IPFSNODEID="$TEST_FAKE_IPFSID" _local_check 2>/dev/null)"

    assert_true '[[ "$out_brain_gpu" == *"82"* ]]'             "check Brain GPU: Power-Score 82"
    assert_true '[[ "$out_brain_gpu" == *"GPU 8Go VRAM"* ]]'   "check Brain GPU: GPU détecté affiché"
    assert_true '[[ "$out_brain_gpu" == *"Optimal"*"GPU"* ]]'  "check Brain GPU: ollama optimal"
    assert_true '[[ "$out_brain_gpu" == *"Recommandé"*"GPU"* ]]' "check Brain GPU: comfyui recommandé"
    assert_false '[[ "$out_brain_gpu" == *"GPU ≥6Go VRAM requis"* ]]' "check Brain GPU: pas de warning GPU manquant"

    # ── Profil : Light ────────────────────────────────────────────────────
    _write_heartbox_light
    local out_light
    out_light="$(IPFSNODEID="$TEST_FAKE_IPFSID" _local_check 2>/dev/null)"

    assert_true '[[ "$out_light" == *"5"* ]]'               "check Light: Power-Score 5"
    assert_true '[[ "$out_light" == *"Light"* ]]'           "check Light: tier Light"
    assert_true '[[ "$out_light" == *"swarm"* ]]'           "check Light: suggestion swarm"
    assert_true '[[ "$out_light" == *"Lent"* ]]'            "check Light: ollama signalé lent"

    # ── Filtre module connu ───────────────────────────────────────────────
    _write_heartbox_brain_nogpu
    local out_filter
    out_filter="$(IPFSNODEID="$TEST_FAKE_IPFSID" _local_check "ollama" 2>/dev/null)"

    assert_true '[[ "$out_filter" == *"ollama"* ]]'         "check filtre ollama: module présent"
    assert_false '[[ "$out_filter" == *"dify"* ]]'          "check filtre ollama: dify absent"
    assert_false '[[ "$out_filter" == *"webtop-http"* ]]'   "check filtre ollama: webtop absent"

    # ── Filtre module inconnu ─────────────────────────────────────────────
    local out_unknown ret_code=0
    out_unknown="$(IPFSNODEID="$TEST_FAKE_IPFSID" _local_check "service_inexistant" 2>/dev/null)" || ret_code=$?

    assert_true '[[ $ret_code -ne 0 ]]'                                 "check filtre inconnu: code erreur ≠ 0"
    assert_true '[[ "$out_unknown" == *"introuvable"* ]]'               "check filtre inconnu: message erreur"
    assert_true '[[ "$out_unknown" == *"Modules disponibles"* ]]'       "check filtre inconnu: liste modules affichée"
    assert_true '[[ "$out_unknown" == *"ollama"* ]]'                    "check filtre inconnu: ollama dans la liste"
    assert_true '[[ "$out_unknown" == *"youtube-antibot"* ]]'           "check filtre inconnu: youtube-antibot dans la liste"

    # ── Restaurer le profil Brain sans GPU ───────────────────────────────
    _write_heartbox_brain_nogpu

    export HOME="$orig_home"
    export PATH="$orig_path"
}

###############################################################################
# GROUPE 6 : cmd_local install — résolution des scripts
###############################################################################
run_tests_install() {
    test_log_info "=== GROUPE 6 : cmd_local install — résolution scripts ==="

    local orig_home="$HOME"
    local orig_path="$PATH"
    export HOME="$TEST_FAKE_HOME"
    export PATH="$TEST_MOCK_BIN:$PATH"

    _source_astrosystemctl

    # Remplacer les helpers pour pointer vers notre environnement de test
    _ia_dir()            { echo "$TEST_WORKDIR/IA"; }
    _modules_list_path() { echo "$TEST_WORKDIR/IA/modules.list"; }

    # ── Sans service : doit trouver install-ai-company.docker.sh ─────────
    local out_noarg ret=0
    out_noarg="$(cmd_local install 2>&1)" || ret=$?
    # On s'attend à ce que le script soit trouvé et exécuté (il est vide, exit 0)
    assert_true '[[ $ret -eq 0 ]]' "cmd_local install (sans arg): script trouvé et exécuté"

    # ── Service avec script direct : install_icecast.sh ──────────────────
    out_noarg="$(cmd_local install "icecast" 2>&1)" || ret=$?
    assert_true '[[ $ret -eq 0 ]]' "cmd_local install icecast: script direct trouvé"

    # ── Résolution via modules.list : youtube-antibot → install_youtube_antibot.sh ──
    out_noarg="$(cmd_local install "youtube-antibot" 2>&1)" || ret=$?
    assert_true '[[ $ret -eq 0 ]]' "cmd_local install youtube-antibot: résolu via modules.list"

    # ── Résolution via modules.list : powerjoular ─────────────────────────
    out_noarg="$(cmd_local install "powerjoular" 2>&1)" || ret=$?
    assert_true '[[ $ret -eq 0 ]]' "cmd_local install powerjoular: résolu via modules.list"

    # ── Service inconnu : doit retourner erreur + liste des modules ───────
    local out_err
    out_err="$(cmd_local install "service_inexistant_$$" 2>&1)" || ret=$?
    assert_true '[[ $ret -ne 0 ]]' "cmd_local install inconnu: code erreur ≠ 0"
    assert_true '[[ "$out_err" == *"introuvable"* ]]'           "cmd_local install inconnu: message erreur"
    assert_true '[[ "$out_err" == *"modules.list"* ]]'          "cmd_local install inconnu: référence modules.list"

    export HOME="$orig_home"
    export PATH="$orig_path"
}

###############################################################################
# GROUPE 7 : Commandes complètes (subprocess)
###############################################################################
run_tests_commands() {
    test_log_info "=== GROUPE 7 : Commandes complètes (subprocess) ==="

    # ── --help ────────────────────────────────────────────────────────────
    local help_out
    help_out="$(_run_astrosystemctl --help 2>/dev/null || true)"
    assert_true '[[ "$help_out" == *"astrosystemctl"* ]]'      "help: contient le nom de l'outil"
    assert_true '[[ "$help_out" == *"list"* ]]'                "help: commande list mentionnée"
    assert_true '[[ "$help_out" == *"connect"* ]]'             "help: commande connect mentionnée"
    assert_true '[[ "$help_out" == *"local"* ]]'               "help: commande local mentionnée"
    assert_true '[[ "$help_out" == *"Power-Score"* ]]'         "help: Power-Score expliqué"
    assert_true '[[ "$help_out" == *"check"* ]]'               "help: local check mentionné"
    assert_true '[[ "$help_out" == *"youtube-antibot"* ]]'     "help: youtube-antibot en exemple"
    assert_true '[[ "$help_out" == *"modules.list"* ]]'        "help: modules.list mentionné"

    # ── local check ───────────────────────────────────────────────────────
    local check_out check_ret=0
    check_out="$(HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" local check 2>/dev/null)" || check_ret=$?

    assert_true '[[ "$check_out" == *"RECOMMANDATIONS"* ]]'    "local check: titre présent"
    assert_true '[[ "$check_out" == *"Power-Score"* ]]'        "local check: Power-Score affiché"
    assert_true '[[ "$check_out" == *"MODULE"* ]]'             "local check: en-tête tableau"
    assert_true '[[ "$check_out" == *"ollama"* ]]'             "local check: ollama dans le tableau"
    assert_true '[[ "$check_out" == *"comfyui"* ]]'            "local check: comfyui dans le tableau"

    # ── local check avec filtre invalide ──────────────────────────────────
    local badfilter_ret=0
    HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" local check "list" >/dev/null 2>&1 \
        || badfilter_ret=$?
    assert_true '[[ $badfilter_ret -ne 0 ]]' "local check list: retour erreur (module 'list' inexistant)"

    # ── local (sans sous-commande) ─────────────────────────────────────────
    local list_out
    list_out="$(HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" local 2>/dev/null)" || true
    assert_true '[[ "$list_out" == *"SERVICES IA"* ]]'         "local (sans arg): tableau services IA"

    # ── status (swarm vide) ───────────────────────────────────────────────
    local status_out
    status_out="$(HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" status 2>/dev/null)" || true
    assert_true '[[ "$status_out" == *"PUBLIÉS"* ]]'           "status: section services publiés"
    assert_true '[[ "$status_out" == *"CONSOMMÉS"* ]]'         "status: section services consommés"
    assert_true '[[ "$status_out" == *"PERSISTANTS"* ]]'       "status: section tunnels persistants"
    assert_true '[[ "$status_out" == *"POWER-SCORE"* ]]'       "status: section Power-Score"
}

###############################################################################
# GROUPE 8 : Gestion des erreurs
###############################################################################
run_tests_errors() {
    test_log_info "=== GROUPE 8 : Gestion des erreurs ==="

    # ── Commande inconnue ─────────────────────────────────────────────────
    local err_out err_ret=0
    err_out="$(_run_astrosystemctl commandeinconnue 2>/dev/null)" || err_ret=$?
    assert_true '[[ $err_ret -ne 0 ]]' "commande inconnue: code de sortie ≠ 0"

    # ── local avec sous-commande inconnue ─────────────────────────────────
    local subcmd_ret=0
    HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" local souscommandemystere 2>/dev/null \
        || subcmd_ret=$?
    assert_true '[[ $subcmd_ret -ne 0 ]]' "local sous-commande inconnue: code erreur"

    # ── connect sans argument ─────────────────────────────────────────────
    local conn_ret=0
    HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" connect 2>/dev/null \
        || conn_ret=$?
    assert_true '[[ $conn_ret -ne 0 ]]' "connect sans argument: code erreur"

    # ── enable sans argument ──────────────────────────────────────────────
    local enable_ret=0
    HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" enable 2>/dev/null \
        || enable_ret=$?
    assert_true '[[ $enable_ret -ne 0 ]]' "enable sans argument: code erreur"

    # ── disable sans argument ─────────────────────────────────────────────
    local disable_ret=0
    HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" disable 2>/dev/null \
        || disable_ret=$?
    assert_true '[[ $disable_ret -ne 0 ]]' "disable sans argument: code erreur"

    # ── local start sans argument ─────────────────────────────────────────
    local start_ret=0
    HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" local start 2>/dev/null \
        || start_ret=$?
    assert_true '[[ $start_ret -ne 0 ]]' "local start sans argument: code erreur"

    # ── local stop sans argument ──────────────────────────────────────────
    local stop_ret=0
    HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" local stop 2>/dev/null \
        || stop_ret=$?
    assert_true '[[ $stop_ret -ne 0 ]]' "local stop sans argument: code erreur"

    # ── local uninstall sans argument ─────────────────────────────────────
    local uninstall_ret=0
    HOME="$TEST_FAKE_HOME" IPFSNODEID="$TEST_FAKE_IPFSID" \
        PATH="$TEST_MOCK_BIN:$PATH" \
        bash "$ASTRO_DIR/tools/astrosystemctl.sh" local uninstall 2>/dev/null \
        || uninstall_ret=$?
    assert_true '[[ $uninstall_ret -ne 0 ]]' "local uninstall sans argument: code erreur"

    # ── Syntaxe bash du script ────────────────────────────────────────────
    local syntax_ret=0
    bash -n "$ASTRO_DIR/tools/astrosystemctl.sh" 2>/dev/null || syntax_ret=$?
    assert_equal "0" "$syntax_ret" "syntaxe bash: astrosystemctl.sh valide"

    bash -n "$ASTRO_DIR/install/install_webtop.sh" 2>/dev/null || syntax_ret=$?
    assert_equal "0" "$syntax_ret" "syntaxe bash: install_webtop.sh valide"

    bash -n "$ASTRO_DIR/install/install_youtube_antibot.sh" 2>/dev/null || syntax_ret=$?
    assert_equal "0" "$syntax_ret" "syntaxe bash: install_youtube_antibot.sh valide"

    bash -n "$ASTRO_DIR/RUNTIME/DRAGON_p2p_ssh.sh" 2>/dev/null || syntax_ret=$?
    assert_equal "0" "$syntax_ret" "syntaxe bash: DRAGON_p2p_ssh.sh valide"
}

###############################################################################
# MAIN
###############################################################################
main() {
    local group="${1:-all}"

    test_log_info "Initialisation environnement de test..."
    _setup_fake_env

    local started=$SECONDS

    case "$group" in
        pure)     run_tests_pure ;;
        env)      run_tests_env ;;
        private)  run_tests_private ;;
        modules)  run_tests_modules ;;
        check)    run_tests_check ;;
        install)  run_tests_install ;;
        commands) run_tests_commands ;;
        errors)   run_tests_errors ;;
        all)
            run_tests_pure
            run_tests_env
            run_tests_private
            run_tests_modules
            run_tests_check
            run_tests_install
            run_tests_commands
            run_tests_errors
            ;;
        *)
            echo "Usage: $0 [pure|env|private|modules|check|install|commands|errors|all]" >&2
            exit 1
            ;;
    esac

    local elapsed=$(( SECONDS - started ))
    echo "" >&2
    echo -e "─────────────────────────────────────────" >&2
    echo -e "${BOLD}Résultats : ${PASS_COUNT}/${TEST_COUNT} réussis · ${FAIL_COUNT} échec(s) · ${elapsed}s${NC}" >&2

    [[ $FAIL_COUNT -eq 0 ]] && exit 0 || exit 1
}

main "${1:-all}"
