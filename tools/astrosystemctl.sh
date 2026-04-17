#!/bin/bash
################################################################################
# astrosystemctl - Cloud P2P de Puissance Astroport
# ----------------------------------------------------------------------------
# Gestion intelligente des services locaux et distants (swarm).
# Compare le Power-Score local avec les nœuds de la constellation pour
# décider si un service doit tourner localement ou être délégué au swarm.
#
# Power-Score : GPU×4 + CPU×2 + RAM×0.5
#   0-10  🌿 Light   → Raspberry Pi (consommateur uniquement)
#   11-40 ⚡ Standard → PC bureautique (petits modèles)
#   41+   🔥 Brain    → GPU dédié (fournisseur swarm)
#
# Auteur  : Fred (support@qo-op.com)
# Licence : AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################

## Résolution du lien symbolique pour trouver my.sh même si appelé via ~/.local/bin/
_SCRIPT="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
MY_PATH="$(dirname "$_SCRIPT")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
. "${MY_PATH}/my.sh"

SWARM_DIR="$HOME/.zen/tmp/swarm"
TUNNELS_ENABLED="$HOME/.zen/tunnels/enabled"
TUNNEL_LOG="$HOME/.zen/tmp/tunnel.log"

# ── Couleurs ──────────────────────────────────────────────────────────────────
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

# ── Power tier label ──────────────────────────────────────────────────────────
power_label() {
    local score="${1:-0}"
    if   [[ $score -gt 40 ]]; then echo "🔥 Brain"
    elif [[ $score -gt 10 ]]; then echo "⚡ Std"
    else                           echo "🌿 Light"
    fi
}

# ── Power-Score local depuis le cache heartbox ────────────────────────────────
get_local_power_score() {
    local cache="$HOME/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json"
    if [[ -s "$cache" ]]; then
        jq -r '.capacities.power_score // 0' "$cache" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

##############################################################################
# list — services locaux + Power-Score
##############################################################################
cmd_list() {
    local cache="$HOME/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json"
    local power_score=0
    local provider_ready="false"

    if [[ -s "$cache" ]]; then
        power_score=$(jq -r '.capacities.power_score // 0'   "$cache" 2>/dev/null)
        provider_ready=$(jq -r '.capacities.provider_ready // false' "$cache" 2>/dev/null)
    fi

    echo -e "${BOLD}=== STATION LOCALE ===${NC}"
    printf "  %-22s %-16s %s\n" "$(hostname)" \
        "Score: ${power_score} $(power_label ${power_score})" \
        "$([[ "$provider_ready" == "true" ]] && echo '✅ Prêt à partager' || echo '🌱 Consommateur')"
    echo ""

    printf "  ${BOLD}%-18s %-8s %-12s${NC}\n" "SERVICE" "PORT" "ÉTAT"
    printf "  %s\n" "$(printf '─%.0s' {1..42})"

    if [[ -s "$cache" ]]; then
        # Services de premier niveau (ipfs, astroport, upassport, g1billet, npm…)
        while IFS= read -r line; do
            printf "  %s\n" "$line"
        done < <(jq -r '
            .services | to_entries[] |
            select(.value | type == "object") |
            select(.key != "ai_company" and .key != "nextcloud" and .key != "webtop") |
            [
                .key[0:16],
                ((.value.port // .value.admin_port // "") | tostring | .[0:6]),
                (if .value.active == true then "✅ ACTIF" else "❌ OFF" end)
            ] | "\(.[0])\(" " * (16 - (.[0]|length)))  \(.[1])\(" " * (6 - (.[1]|length)))  \(.[2])"
        ' "$cache" 2>/dev/null)

        # Stack IA
        echo ""
        printf "  ${BOLD}%-18s %-8s %-12s %-22s${NC}\n" "SERVICE IA" "PORT" "ÉTAT" "MODÈLES"
        printf "  %s\n" "$(printf '─%.0s' {1..62})"
        jq -r '
            .services.ai_company | to_entries[] |
            [
                .key[0:16],
                ((.value.port // "") | tostring | .[0:6]),
                (if .value.active == true then "✅" else "❌" end),
                ((.value.models // []) | join(",") | .[0:20])
            ] | "\(.[0])\(" " * (16 - (.[0]|length)))  \(.[1])\(" " * (6 - (.[1]|length)))  \(.[2])  \(.[3])"
        ' "$cache" 2>/dev/null | while read -r l; do printf "  %s\n" "$l"; done
    fi

    echo ""
    echo -e "  ${BOLD}Services P2P locaux proposés au swarm :${NC}"
    local found=0
    for s in "$HOME/.zen/tmp/${IPFSNODEID}"/x_*.sh; do
        [[ -f "$s" ]] || continue
        local slug port
        slug=$(basename "$s" | sed 's/x_//;s/\.sh//')
        port=$(grep -oP 'NATIVE_PORT="\K\d+' "$s" 2>/dev/null | head -1 || \
               grep -oP '(PORT|LPORT)="\K\d+' "$s" 2>/dev/null | head -1 || echo "?")
        printf "    %-18s port %s\n" "$slug" "$port"
        ((found++))
    done
    [[ $found -eq 0 ]] && echo "    (aucun service P2P local déclaré)"
    echo ""
}

##############################################################################
# list-remote — catalogue des services GPU dans le swarm
##############################################################################
cmd_list_remote() {
    local filter_service="${1:-}"

    echo -e "${BOLD}=== SERVICES SWARM (P2P) ===${NC}"
    echo ""

    if [[ ! -d "$SWARM_DIR" ]] || [[ -z "$(ls -A "$SWARM_DIR" 2>/dev/null)" ]]; then
        echo "  Aucun nœud dans le swarm (répertoire $SWARM_DIR vide)."
        return 1
    fi

    printf "  ${BOLD}%-18s %-24s %-12s %-22s %-8s${NC}\n" \
        "SERVICE" "NODE (fin)" "POWER" "MODÈLES/CAPITAINE" "LATENCE"
    printf "  %s\n" "$(printf '─%.0s' {1..90})"

    local found=0
    for node_path in "$SWARM_DIR"/*/; do
        local node_id json power_score provider_ready dragon_services node_ip captain
        node_id=$(basename "$node_path")
        json="$node_path/12345.json"
        [[ -s "$json" ]] || continue

        power_score=$(jq -r '.capacities.power_score // 0'    "$json" 2>/dev/null || echo 0)
        provider_ready=$(jq -r '.capacities.provider_ready // false' "$json" 2>/dev/null)
        dragon_services=$(jq -r '.dragon_services // ""'           "$json" 2>/dev/null)
        node_ip=$(jq -r '.myIP // ""'                              "$json" 2>/dev/null)
        captain=$(jq -r '.captain // "?"'                         "$json" 2>/dev/null | cut -d'@' -f1)

        [[ -z "$dragon_services" ]] && continue

        # Mesure latence (timeout 2s pour ne pas bloquer)
        local latency="N/A"
        if [[ -n "$node_ip" && "$node_ip" != "null" ]]; then
            latency=$(ping -c 1 -W 2 "$node_ip" 2>/dev/null \
                | grep -oP 'time=\K[\d.]+' | head -1)
            [[ -n "$latency" ]] && latency="${latency}ms" || latency="timeout"
        fi

        IFS=',' read -ra services <<< "$dragon_services"
        for svc in "${services[@]}"; do
            svc="${svc// /}"
            [[ -z "$svc" ]] && continue
            [[ -n "$filter_service" && "$svc" != "$filter_service" ]] && continue

            # Modèles Ollama si disponible
            local specs=""
            if [[ "$svc" == "ollama" ]]; then
                specs=$(jq -r '.services.ai_company.ollama.models // [] | join(",")' \
                    "$json" 2>/dev/null | cut -c1-20)
            fi
            [[ -z "$specs" ]] && specs="${captain}"

            local node_short="...${node_id: -14}"
            printf "  %-18s %-24s %-12s %-22s %-8s\n" \
                "${svc}" "${node_short}" \
                "${power_score} $(power_label ${power_score})" \
                "${specs}" "${latency}"
            ((found++))
        done
    done

    if [[ $found -eq 0 ]]; then
        echo "  Aucun nœud fournisseur de services trouvé dans le swarm."
        echo "  Les stations avec dragon_services et power_score apparaîtront ici."
    fi
    echo ""
}

##############################################################################
# _find_best_node — cherche le meilleur nœud swarm pour un service
# Retourne : node_id ou "" si non trouvé
##############################################################################
_find_best_node() {
    local service="$1"
    local best_node="" best_score=-1

    for node_path in "$SWARM_DIR"/*/; do
        local nid json dragon score
        nid=$(basename "$node_path")
        json="$node_path/12345.json"
        [[ -s "$json" ]] || continue

        dragon=$(jq -r '.dragon_services // ""' "$json" 2>/dev/null)
        # Vérifie que le service est dans dragon_services ET que le script x_ existe
        [[ "$dragon" != *"$service"* ]] && continue
        [[ ! -f "$node_path/x_${service}.sh" ]] && continue

        score=$(jq -r '.capacities.power_score // 0' "$json" 2>/dev/null || echo 0)
        if [[ ${score:-0} -gt ${best_score:-0} ]]; then
            best_score=$score
            best_node=$nid
        fi
    done
    echo "$best_node"
}

##############################################################################
# connect — connecte à un service (auto ou service@node)
##############################################################################
cmd_connect() {
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        echo "Usage: astrosystemctl connect <service[@node]>"
        echo "  ex:  astrosystemctl connect ollama"
        echo "  ex:  astrosystemctl connect ollama@12D3Koo..."
        return 1
    fi

    local service="${target%%@*}"
    local node_id="${target##*@}"
    [[ "$node_id" == "$service" ]] && node_id=""

    # ── Vérification locale d'abord ───────────────────────────────────────────
    local local_port=""
    case "$service" in
        ollama)               local_port="11434" ;;
        comfyui)              local_port="8188"  ;;
        qdrant)               local_port="6333"  ;;
        open_webui|webui)     local_port="8000"  ;;
        dify)                 local_port="8010"  ;;
        nextcloud)            local_port="8001"  ;;
        stable_diffusion|sd)  local_port="7860"  ;;
    esac
    if [[ -n "$local_port" ]] && ss -tln 2>/dev/null | grep -q ":${local_port} "; then
        echo "✅ ${service} disponible localement → http://127.0.0.1:${local_port}"
        return 0
    fi

    # ── Recherche du meilleur nœud si non spécifié ────────────────────────────
    if [[ -z "$node_id" ]]; then
        echo "🔍 Recherche du meilleur nœud swarm pour '${service}'..."
        node_id=$(_find_best_node "$service")

        if [[ -z "$node_id" ]]; then
            echo "❌ Service '${service}' introuvable dans le swarm."
            echo "   Lancez : astrosystemctl list-remote"
            return 1
        fi

        local score
        score=$(jq -r '.capacities.power_score // 0' "$SWARM_DIR/$node_id/12345.json" 2>/dev/null)
        echo "✅ Meilleur nœud : ...${node_id: -14} (score: ${score} $(power_label ${score}))"
    fi

    # ── Trouver le script tunnel ───────────────────────────────────────────────
    local tunnel_script="$SWARM_DIR/${node_id}/x_${service}.sh"
    if [[ ! -f "$tunnel_script" ]]; then
        # Essai insensible à la casse
        tunnel_script=$(find "$SWARM_DIR/${node_id}/" -maxdepth 1 \
            -iname "x_${service}.sh" 2>/dev/null | head -1)
    fi
    if [[ -z "$tunnel_script" || ! -f "$tunnel_script" ]]; then
        echo "❌ Script tunnel introuvable : $SWARM_DIR/${node_id}/x_${service}.sh"
        return 1
    fi

    # ── Port du tunnel ────────────────────────────────────────────────────────
    local port
    port=$(grep -oP 'NATIVE_PORT="\K\d+' "$tunnel_script" 2>/dev/null | head -1 \
        || grep -oP '(PORT|LPORT)="\K\d+' "$tunnel_script" 2>/dev/null | head -1 \
        || grep -oP 'tcp/\K\d+' "$tunnel_script" 2>/dev/null | head -1 \
        || echo "")

    echo "🚀 Connexion ${service}@...${node_id: -14} (port: ${port:-?})..."
    mkdir -p "$(dirname "$TUNNEL_LOG")"
    bash "$tunnel_script" >> "$TUNNEL_LOG" 2>&1 &
    sleep 2

    # ── Vérification tunnel établi ────────────────────────────────────────────
    if ipfs p2p ls 2>/dev/null | grep -qi "${service}"; then
        echo "✅ Tunnel ${service} établi"
    else
        echo "⚠️  Tunnel peut ne pas être encore établi — vérifiez : ipfs p2p ls"
    fi

    # ── Proxy NPM dynamique (optionnel) ───────────────────────────────────────
    if [[ -n "$port" ]] && [[ -f "${MY_PATH}/setup_npm_dynamic.sh" ]]; then
        echo "🔧 Création proxy NPM ${service}.${myDOMAIN:-local} → :${port}..."
        bash "${MY_PATH}/setup_npm_dynamic.sh" "$service" "$port" 2>/dev/null \
            && true \
            || echo "ℹ️  NPM proxy non créé (NPM indisponible ou domaine copylaradio.com)"
    fi

    echo ""
    [[ -n "$port" ]] && echo "  → http://127.0.0.1:${port}"
    [[ -n "$myDOMAIN" && -n "$port" ]] && echo "  → https://${service}.${myDOMAIN}"
}

##############################################################################
# enable — rend un tunnel persistant (watchdog 20h12)
##############################################################################
cmd_enable() {
    local target="${1:-}"
    [[ -z "$target" ]] && echo "Usage: astrosystemctl enable <service[@node]>" && return 1

    local service="${target%%@*}"
    local node_id="${target##*@}"
    [[ "$node_id" == "$service" ]] && node_id=""

    # Trouver le nœud si non spécifié
    if [[ -z "$node_id" ]]; then
        node_id=$(_find_best_node "$service")
        [[ -z "$node_id" ]] && echo "❌ Service '${service}' introuvable dans le swarm" && return 1
    fi

    local tunnel_script="$SWARM_DIR/${node_id}/x_${service}.sh"
    [[ ! -f "$tunnel_script" ]] && \
        echo "❌ Script introuvable : $tunnel_script" && return 1

    mkdir -p "$TUNNELS_ENABLED"
    local link="$TUNNELS_ENABLED/x_${service}_${node_id: -8}.sh"

    # Wrapper qui appelle le script original (chemin absolu)
    cat > "$link" << WRAPPER_EOF
#!/bin/bash
## astrosystemctl enabled tunnel: ${service}@${node_id}
## Géré par le watchdog de 20h12.process.sh
## NE PAS MODIFIER MANUELLEMENT — utiliser astrosystemctl disable ${service}
SERVICE="${service}"
NODE_ID="${node_id}"
TUNNEL_SCRIPT="${tunnel_script}"
[[ -f "\${TUNNEL_SCRIPT}" ]] && bash "\${TUNNEL_SCRIPT}" "\$@" || \
    echo "WARN: script tunnel introuvable: \${TUNNEL_SCRIPT}" >&2
WRAPPER_EOF
    chmod +x "$link"

    echo "✅ Tunnel ${service}@...${node_id: -14} persistant (watchdog ON)"
    echo "   → $link"

    # Connexion immédiate
    cmd_connect "${service}@${node_id}"
}

##############################################################################
# disable — retire un tunnel de la surveillance automatique
##############################################################################
cmd_disable() {
    local service="${1:-}"
    [[ -z "$service" ]] && echo "Usage: astrosystemctl disable <service>" && return 1

    local found=0
    for link in "$TUNNELS_ENABLED"/x_${service}*.sh; do
        [[ -f "$link" ]] || continue
        # Fermer le tunnel P2P actif si possible
        local proto_pattern="${service}"
        local proto_line
        proto_line=$(ipfs p2p ls 2>/dev/null | grep -i "$proto_pattern" | head -1)
        if [[ -n "$proto_line" ]]; then
            local proto
            proto=$(echo "$proto_line" | awk '{print $1}')
            ipfs p2p close -p "$proto" 2>/dev/null && echo "  Tunnel P2P fermé: $proto"
        fi
        rm -f "$link"
        echo "✅ Tunnel ${service} désactivé : $(basename "$link")"
        ((found++))
    done
    [[ $found -eq 0 ]] && echo "ℹ️  Aucun tunnel persistant pour '${service}'"
}

##############################################################################
# status — état des tunnels actifs et persistants
##############################################################################
cmd_status() {
    echo -e "${BOLD}=== TUNNELS IPFS P2P ACTIFS ===${NC}"
    local active_p2p
    active_p2p=$(ipfs p2p ls 2>/dev/null)

    if [[ -z "$active_p2p" ]]; then
        echo "  Aucun tunnel IPFS P2P actif."
    else
        printf "  ${BOLD}%-35s %-22s %-20s${NC}\n" "PROTOCOLE" "LOCAL" "CIBLE"
        printf "  %s\n" "$(printf '─%.0s' {1..80})"
        echo "$active_p2p" | while read -r line; do
            printf "  %s\n" "$line"
        done
    fi

    echo ""
    echo -e "${BOLD}=== TUNNELS PERSISTANTS (enabled) ===${NC}"
    if [[ -d "$TUNNELS_ENABLED" ]] && [[ -n "$(ls -A "$TUNNELS_ENABLED" 2>/dev/null)" ]]; then
        for link in "$TUNNELS_ENABLED"/x_*.sh; do
            [[ -f "$link" ]] || continue
            local svc
            svc=$(basename "$link" | sed 's/x_//;s/_[^_]*\.sh$//')
            local is_active
            is_active=$(echo "$active_p2p" | grep -ci "$svc" || echo 0)
            if [[ $is_active -gt 0 ]]; then
                echo -e "  ${GREEN}✅ ${svc}${NC} (tunnel actif)"
            else
                echo -e "  ${YELLOW}⏳ ${svc}${NC} (watchdog relancera au prochain 20h12)"
            fi
        done
    else
        echo "  Aucun tunnel persistant. Utilisez : astrosystemctl enable <service>"
    fi

    echo ""
    echo -e "${BOLD}=== POWER-SCORE LOCAL ===${NC}"
    local local_score
    local_score=$(get_local_power_score)
    echo "  Score: ${local_score} $(power_label ${local_score})"
    if   [[ ${local_score:-0} -gt 40 ]]; then
        echo "  Mode : 🔥 Brain-Node — fournisseur GPU pour le swarm"
    elif [[ ${local_score:-0} -gt 10 ]]; then
        echo "  Mode : ⚡ Standard — peut héberger de petits modèles"
    else
        echo "  Mode : 🌿 Light — délègue le calcul au swarm"
    fi
    echo ""
}

##############################################################################
# Main
##############################################################################
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
    list)           cmd_list        "$@" ;;
    list-remote)    cmd_list_remote "$@" ;;
    connect)        cmd_connect     "$@" ;;
    enable)         cmd_enable      "$@" ;;
    disable)        cmd_disable     "$@" ;;
    status)         cmd_status      "$@" ;;
    help|--help|-h)
        cat << 'HELP'
astrosystemctl — Cloud P2P de Puissance Astroport

Usage: astrosystemctl <commande> [service[@node]]

Commandes :
  list                   Services locaux + Power-Score de cette station
  list-remote [service]  Services GPU disponibles dans le swarm
  connect  <svc[@node]>  Connecte au meilleur nœud pour ce service
  enable   <svc[@node]>  Tunnel persistant (watchdog 20h12)
  disable  <service>     Retire de la surveillance automatique
  status                 Tunnels actifs + persistants + Power-Score

Power-Score = GPU×4 + CPU×2 + RAM×0.5
  0-10  🌿 Light   → consommateur (utilise le swarm)
  11-40 ⚡ Standard → peut héberger de petits modèles localement
  41+   🔥 Brain    → fournisseur GPU pour la constellation

Exemples :
  astrosystemctl list-remote                # Qui a un GPU dans l'essaim ?
  astrosystemctl connect ollama             # Meilleur nœud ollama automatique
  astrosystemctl connect comfyui@12D3Koo…  # Nœud spécifique
  astrosystemctl enable ollama              # Watchdog: tunnel toujours actif
  astrosystemctl disable ollama             # Arrêt du watchdog

Tunnels persistants : ~/.zen/tunnels/enabled/
Logs tunnels       : ~/.zen/tmp/tunnel.log
HELP
        ;;
    *)
        echo "Commande inconnue : '$COMMAND'. Utilisez : astrosystemctl --help"
        exit 1
        ;;
esac
