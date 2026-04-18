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
    local storage_ready="false"

    if [[ -s "$cache" ]]; then
        power_score=$(jq -r '.capacities.power_score // 0'      "$cache" 2>/dev/null)
        provider_ready=$(jq -r '.capacities.provider_ready // false' "$cache" 2>/dev/null)
        storage_ready=$(jq -r '.capacities.storage_ready // false'   "$cache" 2>/dev/null)
    fi

    local role_label=""
    [[ "$provider_ready" == "true" ]] && role_label+="⚡ Calcul "
    [[ "$storage_ready"  == "true" ]] && role_label+="🗄️ Vault"
    [[ -z "$role_label" ]]            && role_label="🌱 Consommateur"

    echo -e "${BOLD}=== STATION LOCALE ===${NC}"
    printf "  %-22s %-16s %s\n" "$(hostname)" \
        "Score: ${power_score} $(power_label ${power_score})" \
        "${role_label}"
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

        # Stack IA — avec indication de la source (local / p2p_tunnel / ssh_tunnel)
        echo ""
        printf "  ${BOLD}%-18s %-8s %-14s %-10s %-20s${NC}\n" "SERVICE IA" "PORT" "ÉTAT" "SOURCE" "MODÈLES"
        printf "  %s\n" "$(printf '─%.0s' {1..74})"
        jq -r '
            .services.ai_company | to_entries[] |
            [
                .key[0:16],
                ((.value.port // "") | tostring | .[0:6]),
                (if .value.active == true then
                    if .value.source == "local" then "✅ LOCAL"
                    elif .value.source == "p2p_tunnel" then "🔗 P2P"
                    elif .value.source == "ssh_tunnel" then "🔒 SSH"
                    else "⚠️  ?" end
                 else "❌ OFF" end),
                (.value.source // "none"),
                ((.value.models // []) | join(",") | .[0:20])
            ] | "\(.[0])\(" " * (16 - (.[0]|length)))  \(.[1])\(" " * (6 - (.[1]|length)))  \(.[2])\(" " * (10 - (.[2]|length)))  \(.[4])"
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

    printf "  ${BOLD}%-18s %-24s %-14s %-14s %-20s %-8s${NC}\n" \
        "SERVICE" "NODE (fin)" "POWER" "CAPITAINE" "MODÈLES" "LATENCE"
    printf "  %s\n" "$(printf '─%.0s' {1..102})"

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
        # Ne lister que les nœuds qui se déclarent providers (services IA locaux)
        [[ "$provider_ready" != "true" ]] && continue

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
            svc="${svc%.sh}"   # certains 12345.json stockent "ollama.sh" au lieu de "ollama"
            [[ -z "$svc" ]] && continue
            [[ -n "$filter_service" && "$svc" != "$filter_service" ]] && continue

            # Garder uniquement les services IA (présents dans ai_company)
            # Exclut automatiquement npm, ssh, strfry, nextcloud*, webtop*, icecast...
            local svc_in_ai
            svc_in_ai=$(jq -r "if .services.ai_company then \
                (.services.ai_company | has(\"${svc}\")) else \"false\" end" \
                "$json" 2>/dev/null || echo "false")
            [[ "$svc_in_ai" != "true" ]] && continue

            # Vérifier que le service est bien LOCAL sur ce nœud (pas un tunnel)
            local svc_source
            svc_source=$(jq -r ".services.ai_company.${svc}.source // \"unknown\"" \
                "$json" 2>/dev/null)
            # Ignorer si c'est un tunnel (ce nœud ne fait que relayer)
            [[ "$svc_source" == "p2p_tunnel" || "$svc_source" == "ssh_tunnel" ]] && continue

            # Modèles Ollama uniquement (colonne séparée du capitaine)
            local specs=""
            if [[ "$svc" == "ollama" ]]; then
                specs=$(jq -r '.services.ai_company.ollama.models // [] | join(",")' \
                    "$json" 2>/dev/null | cut -c1-20)
            fi

            local node_short="...${node_id: -14}"
            printf "  %-18s %-24s %-14s %-14s %-20s %-8s\n" \
                "${svc}" "${node_short}" \
                "${power_score} $(power_label ${power_score})" \
                "${captain}" "${specs}" "${latency}"
            ((found++))
        done
    done

    if [[ $found -eq 0 ]]; then
        echo "  Aucun nœud fournisseur de services trouvé dans le swarm."
        echo "  Les stations avec dragon_services et power_score apparaîtront ici."
    fi
    echo ""

    ## ── Nœuds Vault (riches en stockage) ─────────────────────────────────────
    ## Séparés des fournisseurs IA : un RPi avec 2 To peut héberger des données
    ## sans avoir de GPU. Affiché même si provider_ready=false.
    echo -e "${BOLD}=== VAULT NODES (STOCKAGE) ===${NC}"
    echo ""
    printf "  ${BOLD}%-24s %-12s %-10s %-10s %-10s %-10s${NC}\n" \
        "NODE (fin)" "CAPITAINE" "ZenCards" "NOSTR" "ESPACE Go" "POWER"
    printf "  %s\n" "$(printf '─%.0s' {1..80})"

    local vault_found=0
    for node_path in "$SWARM_DIR"/*/; do
        local node_id json storage_ready zencard_slots nostr_slots avail_gb v_score v_captain
        node_id=$(basename "$node_path")
        json="$node_path/12345.json"
        [[ -s "$json" ]] || continue

        storage_ready=$(jq -r '.capacities.storage_ready // false' "$json" 2>/dev/null)
        [[ "$storage_ready" != "true" ]] && continue

        zencard_slots=$(jq -r '.capacities.zencard_slots  // 0'              "$json" 2>/dev/null || echo 0)
        nostr_slots=$(jq -r  '.capacities.nostr_slots     // 0'              "$json" 2>/dev/null || echo 0)
        avail_gb=$(jq -r     '.capacities.available_space_gb // 0'           "$json" 2>/dev/null || echo 0)
        v_score=$(jq -r      '.capacities.power_score        // 0'           "$json" 2>/dev/null || echo 0)
        v_captain=$(jq -r    '.captain // "?"'                               "$json" 2>/dev/null | cut -d'@' -f1)

        local node_short="...${node_id: -14}"
        printf "  %-24s %-12s %-10s %-10s %-10s %-10s\n" \
            "${node_short}" "${v_captain}" \
            "${zencard_slots} 🏠" "${nostr_slots} 📡" \
            "${avail_gb} Go" \
            "${v_score} $(power_label ${v_score})"
        ((vault_found++))
    done

    if [[ $vault_found -eq 0 ]]; then
        echo "  Aucun nœud Vault dans le swarm (seuil : ≥128 Go NextCloud ou ≥100 Go IPFS)."
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
        # Normaliser dragon_services (retirer suffixes .sh éventuels)
        dragon=$(echo "$dragon" | sed 's/\.sh\b//g')
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
        ollama)                      local_port="11434" ;;
        comfyui)                     local_port="8188"  ;;
        qdrant)                      local_port="6333"  ;;
        open_webui|webui|open-webui) local_port="8000"  ;;
        dify)                        local_port="8010"  ;;
        nextcloud)                   local_port="8001"  ;;
        mirofish)                    local_port="5050"  ;;
        orpheus)                     local_port="5005"  ;;
        perplexica|vane)             local_port="3002"  ;;
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
    if [[ $found -eq 0 ]]; then
        echo "ℹ️  Aucun tunnel persistant pour '${service}'"
    fi
    return 0
}

##############################################################################
# .env helpers — gestion de DRAGON_PRIVATE_SERVICES
##############################################################################
_env_file() {
    echo "$HOME/.zen/Astroport.ONE/.env"
}

# Lit la liste DRAGON_PRIVATE_SERVICES depuis .env
_priv_list() {
    local env
    env="$(_env_file)"
    grep -oP 'DRAGON_PRIVATE_SERVICES="\K[^"]*' "$env" 2>/dev/null \
        || grep -oP "DRAGON_PRIVATE_SERVICES='\K[^']*" "$env" 2>/dev/null \
        || grep -oP 'DRAGON_PRIVATE_SERVICES=\K\S+' "$env" 2>/dev/null \
        | tr -d '"' | tr -d "'" | head -1 \
        || echo ""
}

# Retourne 0 si le service est privé (non partagé)
_is_private() {
    echo " $(_priv_list) " | grep -qw "$1"
}

# Ajoute (add) ou retire (remove) un service de DRAGON_PRIVATE_SERVICES dans .env
_env_set_private() {
    local svc="$1" action="$2"
    local env
    env="$(_env_file)"
    local current
    current=$(_priv_list)

    local new_val
    if [[ "$action" == "add" ]]; then
        echo " ${current} " | grep -qw "$svc" && {
            echo "ℹ️  '${svc}' est déjà privé (non partagé)"; return 0
        }
        new_val="${current:+$current }${svc}"
    else
        new_val=$(echo "$current" | tr ' ' '\n' | grep -vxF "$svc" \
            | tr '\n' ' ' | sed 's/^ *//;s/ *$//')
    fi

    if [[ -f "$env" ]] && grep -qE '^DRAGON_PRIVATE_SERVICES=' "$env" 2>/dev/null; then
        sed -i "s|^DRAGON_PRIVATE_SERVICES=.*|DRAGON_PRIVATE_SERVICES=\"${new_val}\"|" "$env"
    else
        echo "DRAGON_PRIVATE_SERVICES=\"${new_val}\"" >> "$env"
    fi
    echo "✅ DRAGON_PRIVATE_SERVICES=\"${new_val}\""
    echo "   → Relancez DRAGON_p2p_ssh.sh pour appliquer"
}

##############################################################################
# status — tunnels publiés (server), consommés (client), persistants, score
##############################################################################
cmd_status() {
    local active_p2p
    active_p2p=$(ipfs p2p ls 2>/dev/null)
    local priv_list
    priv_list=$(_priv_list)

    # ── Tunnels publiés par cette station (server-side : ipfs p2p listen) ────
    # Format ipfs p2p ls côté serveur : /x/slug-NODEID  /p2p/NODEID  /ip4/.../tcp/PORT
    echo -e "${BOLD}=== SERVICES PUBLIÉS AU SWARM ===${NC}"
    echo -e "  Services que la constellation peut consommer depuis cette station."
    echo ""
    printf "  ${BOLD}%-22s %-8s %-12s${NC}\n" "SERVICE" "PORT" "PARTAGE"
    printf "  %s\n" "$(printf '─%.0s' {1..44})"

    local has_server=0
    while IFS= read -r line; do
        [[ "$line" =~ ^/x/ ]] || continue
        local col2
        col2=$(echo "$line" | awk '{print $2}')
        # Côté serveur : col2 = /p2p/NODEID (ce nœud lui-même)
        [[ "$col2" != /p2p/* ]] && continue

        local proto slug port
        proto=$(echo "$line" | awk '{print $1}')
        port=$(echo "$line" | awk '{print $3}' | grep -oP 'tcp/\K[0-9]+')
        # Retirer /x/ et le suffixe -IPFSNODEID (bash natif, pas de sed)
        slug="${proto#/x/}"
        slug="${slug%-${IPFSNODEID}}"

        local share_str
        if echo " $priv_list " | grep -qw "$slug"; then
            share_str="🔒 Privé"
        else
            share_str="🌐 Partagé"
        fi
        printf "  %-22s %-8s %s\n" "$slug" "${port:-?}" "$share_str"
        ((has_server++))
    done <<< "$active_p2p"
    [[ $has_server -eq 0 ]] && echo "  (aucun service publié — DRAGON_p2p_ssh.sh inactif ?)"
    echo ""

    # ── Tunnels consommés depuis le swarm (client-side : ipfs p2p forward) ───
    # Format côté client : /x/slug-REMOTEID  /ip4/127.0.0.1/tcp/LPORT  /p2p/REMOTEID
    echo -e "${BOLD}=== SERVICES DISTANTS CONSOMMÉS ===${NC}"
    echo -e "  Connexions vers d'autres stations (tunnels entrants)."
    echo ""
    printf "  ${BOLD}%-22s %-12s %-38s${NC}\n" "SERVICE" "PORT LOCAL" "NŒUD DISTANT"
    printf "  %s\n" "$(printf '─%.0s' {1..74})"

    local has_client=0
    while IFS= read -r line; do
        [[ "$line" =~ ^/x/ ]] || continue
        local col2
        col2=$(echo "$line" | awk '{print $2}')
        # Côté client : col2 = /ip4/... ou /ip6/...
        [[ "$col2" != /ip4/* && "$col2" != /ip6/* ]] && continue

        local proto lport remote_id slug
        proto=$(echo "$line" | awk '{print $1}')
        lport=$(echo "$col2" | grep -oP 'tcp/\K[0-9]+')
        remote_id=$(echo "$line" | awk '{print $3}')
        remote_id="${remote_id#/p2p/}"
        slug="${proto#/x/}"
        slug="${slug%-${remote_id}}"

        printf "  %-22s %-12s ...%s\n" "$slug" "${lport:-?}" "${remote_id: -22}"
        ((has_client++))
    done <<< "$active_p2p"
    [[ $has_client -eq 0 ]] && echo "  (aucun service distant connecté)"
    echo ""

    # ── Tunnels persistants (watchdog 20h12) ─────────────────────────────────
    echo -e "${BOLD}=== TUNNELS PERSISTANTS (watchdog) ===${NC}"
    if [[ -d "$TUNNELS_ENABLED" ]] && [[ -n "$(ls -A "$TUNNELS_ENABLED" 2>/dev/null)" ]]; then
        for link in "$TUNNELS_ENABLED"/x_*.sh; do
            [[ -f "$link" ]] || continue
            local svc
            svc=$(basename "$link" | sed 's/x_//;s/_[^_]*\.sh$//')
            if echo "$active_p2p" | grep -qi "$svc"; then
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
    if [[ -n "$priv_list" ]]; then
        echo -e "  ${BOLD}Services privés (non partagés) :${NC} ${priv_list}"
        echo "  Modifier : astrosystemctl local share/hide <service>"
    else
        echo "  Tous les services actifs sont partagés avec la constellation."
        echo "  Pour rendre un service privé : astrosystemctl local hide <service>"
    fi
    echo ""
}

##############################################################################
# _ia_dir — trouve le répertoire IA/ depuis le path du script (tools/)
##############################################################################
_ia_dir() {
    local candidates=("${MY_PATH}/../IA" "${MY_PATH}/IA" "$HOME/.zen/Astroport.ONE/IA")
    for d in "${candidates[@]}"; do
        [[ -d "$d" ]] && { echo "$(cd "$d" && pwd)"; return; }
    done
    echo ""
}

# Normalise le nom de fichier .me.sh en clé heartbox_analysis.json
# ex: open-webui → open_webui, dify.ai → dify
_svc_to_hb_key() {
    echo "$1" | sed 's/\.ai$//' | tr '-' '_'
}

# Trouve le fichier .me.sh pour un nom de service (tirets ou underscores)
_find_me_sh() {
    local ia_dir="$1" svc="$2"
    local alt
    alt="${svc//_/-}"   # open_webui → open-webui
    for candidate in "${ia_dir}/${svc}.me.sh" "${ia_dir}/${alt}.me.sh"; do
        [[ -f "$candidate" ]] && { echo "$candidate"; return; }
    done
    # Recherche insensible à la casse en dernier recours
    find "$ia_dir" -maxdepth 1 -iname "${svc}.me.sh" 2>/dev/null | head -1
}

##############################################################################
# _local_list — tableau de tous les connecteurs IA disponibles
##############################################################################
_local_list() {
    local ia_dir="${1:-}"
    local cache="$HOME/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json"

    echo -e "${BOLD}=== SERVICES IA LOCAUX ===${NC}"
    echo ""

    if [[ -z "$ia_dir" || ! -d "$ia_dir" ]]; then
        echo "  ⚠️  Répertoire IA/ introuvable (attendu: ${MY_PATH}/../IA)"
        return 1
    fi

    if [[ ! -s "$cache" ]]; then
        echo -e "  ${YELLOW}ℹ️  heartbox_analysis.json absent — run: heartbox_analysis.sh update${NC}"
        echo ""
    fi

    printf "  ${BOLD}%-18s %-6s %-8s %-14s %-14s %-18s${NC}\n" \
        "SERVICE" "PORT" "ÉTAT" "SOURCE" "PARTAGE" "ACTION"
    printf "  %s\n" "$(printf '─%.0s' {1..80})"

    local count=0
    for me_sh in "$ia_dir"/*.me.sh; do
        [[ -f "$me_sh" ]] || continue
        local svc hb_key
        svc=$(basename "$me_sh" | sed 's/\.me\.sh//')
        hb_key=$(_svc_to_hb_key "$svc")

        # Port (cherche le pattern PORT=NNN dans le .me.sh)
        local port
        port=$(grep -oP '(?i)[A-Z_]+PORT\s*=\s*\$\{[^}]+:-\K[0-9]+' "$me_sh" 2>/dev/null \
               | head -1)
        [[ -z "$port" ]] && port=$(grep -oP '(?i)PORT\s*=\s*\K[0-9]{4,5}' "$me_sh" \
               2>/dev/null | head -1)
        [[ -z "$port" ]] && port="?"

        # Statut depuis heartbox cache
        local active="false" src="none"
        if [[ -s "$cache" ]]; then
            active=$(jq -r ".services.ai_company.${hb_key}.active // \"false\"" \
                "$cache" 2>/dev/null || echo "false")
            src=$(jq -r    ".services.ai_company.${hb_key}.source // \"none\""  \
                "$cache" 2>/dev/null || echo "none")
        fi

        # Indicateurs texte (sans ANSI pour alignement propre)
        local status action share_str
        if [[ "$active" == "true" ]]; then
            case "$src" in
                local)       status="✅ LOCAL" ;  action="stop" ;;
                p2p_tunnel)  status="🔗 P2P"   ;  action="(tunnel distant)" ;;
                ssh_tunnel)  status="🔒 SSH"   ;  action="(tunnel SSH)" ;;
                *)           status="⚠️  ?"    ;  action="?" ;;
            esac
        else
            status="❌ OFF"
            # Vérifier si un script d'install dédié existe
            local astro_dir
            astro_dir="$(cd "$ia_dir/.." && pwd)"
            if [[ -f "${astro_dir}/install/install_${hb_key}.sh" ]]; then
                action="start|install ${hb_key}"
            else
                action="start|install"
            fi
        fi

        # Statut de partage (DRAGON_PRIVATE_SERVICES)
        if _is_private "$svc" || _is_private "$hb_key"; then
            share_str="🔒 Privé"
        else
            share_str="🌐 Partagé"
        fi

        printf "  %-18s %-6s %-8s  %-14s %-14s %s\n" \
            "$svc" "$port" "$status" "$src" "$share_str" "$action"
        ((count++))
    done

    echo ""
    [[ $count -eq 0 ]] && echo "  (aucun connecteur IA trouvé dans $ia_dir)"

    echo -e "  ${BOLD}Commandes :${NC}"
    echo "  astrosystemctl local start   <service>   # Démarrer via connecteur .me.sh"
    echo "  astrosystemctl local stop    <service>   # Arrêter"
    echo "  astrosystemctl local install [service]   # Installer stack IA (docker)"
    echo "  astrosystemctl local feed                # Alimenter MiroFish RAG"
    echo ""
}

##############################################################################
# _check_requirements — vérifie que la station peut faire tourner un service
# Retourne 1 si bloquant, 0 sinon. Passer "force" en $2 pour ignorer warnings.
##############################################################################
_check_requirements() {
    local svc="$1" force="${2:-}"
    local cache="$HOME/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json"

    local score=0 avail_gb=0
    if [[ -s "$cache" ]]; then
        score=$(jq -r    '.capacities.power_score        // 0' "$cache" 2>/dev/null || echo 0)
        avail_gb=$(jq -r '.capacities.available_space_gb // 0' "$cache" 2>/dev/null || echo 0)
    fi

    local has_docker=false
    command -v docker >/dev/null 2>&1 && has_docker=true

    case "$svc" in
        dify|open-webui|open_webui|mirofish|qdrant|vane|orpheus)
            if [[ "$has_docker" == "false" ]]; then
                echo -e "${RED}❌  Docker non installé — requis pour ${svc}${NC}"
                echo    "    https://docs.docker.com/engine/install/"
                return 1
            fi ;;
    esac

    case "$svc" in
        ollama)
            if [[ ${score:-0} -lt 11 ]]; then
                echo -e "${YELLOW}⚠️  Power-Score ${score} 🌿 Light — Ollama sera très lent (CPU uniquement)${NC}"
                echo    "   Alternative recommandée : astrosystemctl connect ollama"
                [[ "$force" != "force" ]] && return 1
            elif [[ ${score:-0} -lt 41 ]]; then
                echo -e "${YELLOW}ℹ️  Power-Score ${score} ⚡ Standard — mode CPU, petits modèles uniquement${NC}"
                echo    "   Recommandé : phi3, tinyllama, gemma:2b  (éviter >7B)"
            fi
            if ! command -v ollama >/dev/null 2>&1; then
                echo -e "${YELLOW}ℹ️  ollama non installé :${NC}"
                echo    "   curl -fsSL https://ollama.com/install.sh | sh && ollama pull phi3"
            fi ;;
        comfyui)
            if [[ ${score:-0} -lt 41 ]]; then
                echo -e "${RED}❌  Power-Score ${score} — ComfyUI nécessite un GPU dédié (🔥 Brain ≥41)${NC}"
                echo    "   Alternative : astrosystemctl connect comfyui"
                [[ "$force" != "force" ]] && return 1
            fi ;;
        dify)
            if command -v bc >/dev/null 2>&1 && [[ $(echo "$avail_gb < 20" | bc 2>/dev/null) -eq 1 ]]; then
                echo -e "${RED}❌  Espace insuffisant : ${avail_gb} Go disponibles (20 Go requis pour Dify)${NC}"
                return 1
            fi
            ss -tln 2>/dev/null | grep -q ':11434 ' || \
                echo -e "${YELLOW}⚠️  Ollama inactif — démarrer d'abord : astrosystemctl local start ollama${NC}" ;;
        open-webui|open_webui|mirofish)
            if command -v bc >/dev/null 2>&1 && [[ $(echo "$avail_gb < 5" | bc 2>/dev/null) -eq 1 ]]; then
                echo -e "${RED}❌  Espace insuffisant : ${avail_gb} Go disponibles (5 Go requis)${NC}"
                return 1
            fi
            ss -tln 2>/dev/null | grep -q ':11434 ' || \
                echo -e "${YELLOW}⚠️  Ollama inactif (port 11434) — ${svc} en dépend${NC}" ;;
        orpheus)
            [[ ${score:-0} -lt 41 ]] && \
                echo -e "${YELLOW}⚠️  Power-Score ${score} — Orpheus TTS est lent sans GPU${NC}" ;;
    esac
    return 0
}

##############################################################################
# _local_uninstall_service — désinstalle un service IA local
# --purge : supprime aussi les volumes/données persistantes
##############################################################################
_local_uninstall_service() {
    local ia_dir="$1" svc="$2" purge="${3:-}"
    local AI_COMPANY_DIR="$HOME/.zen/ai-company"

    echo "🗑️  Désinstallation ${svc}..."
    [[ "$purge" == "--purge" ]] && \
        echo -e "${YELLOW}  ⚠️  Mode --purge : volumes et données supprimés${NC}"

    if command -v docker >/dev/null 2>&1; then
        local container_id
        container_id=$(docker ps -a --filter "name=${svc}" --format '{{.ID}}' 2>/dev/null | head -1)
        if [[ -n "$container_id" ]]; then
            local container_name
            container_name=$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null | tr -d '/')
            docker stop "$container_id" 2>/dev/null
            docker rm   "$container_id" 2>/dev/null
            echo "✅ Container ${container_name} supprimé"
            if [[ "$purge" == "--purge" ]]; then
                docker volume ls -q --filter "name=${svc}" 2>/dev/null \
                    | xargs -r docker volume rm 2>/dev/null && echo "  Volumes supprimés"
                local data_dir="${AI_COMPANY_DIR}/${svc}_data"
                [[ -d "$data_dir" ]] && rm -rf "$data_dir" && echo "  Données supprimées : $data_dir"
            fi
            return 0
        fi

        local compose_dirs=("${AI_COMPANY_DIR}" "${AI_COMPANY_DIR}/dify/docker")
        for cdir in "${compose_dirs[@]}"; do
            for cf in "${cdir}/docker-compose.yml" "${cdir}/docker-compose.yaml" "${cdir}/compose.yml"; do
                [[ -f "$cf" ]] || continue
                grep -q "${svc}" "$cf" 2>/dev/null || continue
                docker compose -f "$cf" stop  "${svc}" 2>/dev/null
                docker compose -f "$cf" rm -f "${svc}" 2>/dev/null
                [[ "$purge" == "--purge" ]] && docker volume ls -q --filter "name=${svc}" 2>/dev/null \
                    | xargs -r docker volume rm 2>/dev/null
                echo "✅ ${svc} désinstallé (compose : ${cf})"
                return 0
            done
        done
    fi

    if systemctl list-unit-files 2>/dev/null | grep -qE "^${svc}\.service"; then
        sudo systemctl stop    "${svc}" 2>/dev/null
        sudo systemctl disable "${svc}" 2>/dev/null
        echo "✅ ${svc} arrêté et désactivé (systemctl)"
        return 0
    fi

    echo "ℹ️  ${svc} : aucune installation locale trouvée"
    return 0
}

##############################################################################
# _local_start_service — démarre un service IA localement (docker / systemctl)
# NOTE : .me.sh = gestionnaire de connexion (local ou P2P), pas de cycle de vie.
#        Cette fonction gère le démarrage réel du processus local.
##############################################################################
_local_start_service() {
    local ia_dir="$1" svc="$2"
    local AI_COMPANY_DIR="$HOME/.zen/ai-company"

    echo "🚀 Démarrage ${svc}..."

    # ── 1. Docker : container dont le nom contient le slug ───────────────────
    if command -v docker >/dev/null 2>&1; then
        local container_id container_name container_st
        container_id=$(docker ps -a --filter "name=${svc}" --format '{{.ID}}' 2>/dev/null \
            | head -1)

        if [[ -n "$container_id" ]]; then
            container_name=$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null \
                | tr -d '/')
            container_st=$(docker inspect --format '{{.State.Status}}' "$container_id" \
                2>/dev/null)

            if [[ "$container_st" == "running" ]]; then
                echo "✅ ${svc} tourne déjà (${container_name})"
                return 0
            fi
            echo "  Container '${container_name}' trouvé (${container_st}) — démarrage..."
            docker start "$container_id" \
                && echo "✅ ${svc} démarré (${container_name})" && return 0
            echo "❌ docker start échoué pour ${container_name}"
        fi

        # ── 1b. docker compose up -d (cherche dans les emplacements connus) ──
        local compose_dirs=(
            "${AI_COMPANY_DIR}"
            "${AI_COMPANY_DIR}/dify/docker"
        )
        for cdir in "${compose_dirs[@]}"; do
            for cf in "${cdir}/docker-compose.yml" "${cdir}/docker-compose.yaml" \
                      "${cdir}/compose.yml"; do
                [[ -f "$cf" ]] || continue
                grep -q "${svc}" "$cf" 2>/dev/null || continue
                echo "  Compose : ${cf}"
                docker compose -f "$cf" up -d "$svc" \
                    && echo "✅ ${svc} démarré via docker compose" && return 0
            done
        done
    fi

    # ── 2. systemctl (ollama, comfyui…) ──────────────────────────────────────
    if systemctl list-unit-files 2>/dev/null | grep -qE "^${svc}\.service"; then
        echo "  Service systemctl trouvé — démarrage..."
        sudo systemctl start "${svc}" \
            && echo "✅ ${svc} démarré (systemctl)" && return 0
    fi

    # ── 3. Non installé ──────────────────────────────────────────────────────
    echo ""
    echo "❌ '${svc}' n'est pas installé localement."
    echo "   Installer la stack IA complète :"
    echo "     astrosystemctl local install"
    echo "   Ou connecter via le swarm (service distant) :"
    echo "     astrosystemctl connect ${svc}"
    return 1
}

##############################################################################
# _local_stop_service — arrête un service IA local ou ferme son tunnel
##############################################################################
_local_stop_service() {
    local ia_dir="$1" svc="$2"

    echo "🛑 Arrêt ${svc}..."

    # ── 1. Docker container en cours d'exécution ─────────────────────────────
    if command -v docker >/dev/null 2>&1; then
        local container_id
        container_id=$(docker ps --filter "name=${svc}" --format '{{.ID}}' 2>/dev/null \
            | head -1)
        if [[ -n "$container_id" ]]; then
            local container_name
            container_name=$(docker inspect --format '{{.Name}}' "$container_id" \
                2>/dev/null | tr -d '/')
            docker stop "$container_id" \
                && echo "✅ ${svc} arrêté (${container_name})" && return 0
        fi
    fi

    # ── 2. systemctl ─────────────────────────────────────────────────────────
    if systemctl is-active --quiet "${svc}" 2>/dev/null; then
        sudo systemctl stop "${svc}" \
            && echo "✅ ${svc} arrêté (systemctl)" && return 0
    fi

    # ── 3. Fermer les tunnels P2P/SSH via le connecteur .me.sh ───────────────
    local me_sh
    me_sh=$(_find_me_sh "$ia_dir" "$svc")
    if [[ -n "$me_sh" ]]; then
        echo "  Fermeture des tunnels ${svc}..."
        bash "$me_sh" OFF
        return $?
    fi

    echo "ℹ️  ${svc} : aucun processus local trouvé"
    return 0
}

##############################################################################
# local — panneau de contrôle des services IA locaux
# Usage : astrosystemctl local [list|start|stop|install|feed] [service]
##############################################################################
cmd_local() {
    local subcmd="${1:-list}"
    shift 2>/dev/null || true
    local service="${1:-}"

    local ia_dir
    ia_dir=$(_ia_dir)

    case "$subcmd" in
        list|"")
            _local_list "$ia_dir"
            ;;

        start)
            [[ -z "$service" ]] && {
                echo "Usage: astrosystemctl local start <service>"
                echo "Services disponibles : astrosystemctl local list"
                return 1
            }
            _check_requirements "$service" "${2:-}" || return 1
            _local_start_service "$ia_dir" "$service"
            ;;

        uninstall)
            [[ -z "$service" ]] && {
                echo "Usage: astrosystemctl local uninstall <service> [--purge]"
                echo "  --purge  supprime aussi les volumes et données"
                return 1
            }
            _local_uninstall_service "$ia_dir" "$service" "${2:-}"
            ;;

        stop|off)
            [[ -z "$service" ]] && {
                echo "Usage: astrosystemctl local stop <service>"
                return 1
            }
            _local_stop_service "$ia_dir" "$service"
            ;;

        install)
            local astro_dir
            [[ -n "$ia_dir" ]] && astro_dir="$(cd "$ia_dir/.." && pwd)" \
                               || astro_dir="${MY_PATH}/.."
            # Script dédié si service spécifié
            local install_script="${astro_dir}/install/install-ai-company.docker.sh"
            if [[ -n "$service" && -f "${astro_dir}/install/install_${service}.sh" ]]; then
                install_script="${astro_dir}/install/install_${service}.sh"
            fi
            if [[ ! -f "$install_script" ]]; then
                echo "❌ Script d'installation introuvable : $install_script"
                return 1
            fi
            echo "📦 Installation ${service:-stack IA complète}..."
            bash "$install_script" "$service"
            ;;

        feed)
            local feed_script="${ia_dir}/feed_mirofish.sh"
            if [[ ! -f "$feed_script" ]]; then
                echo "❌ feed_mirofish.sh introuvable : $feed_script"
                return 1
            fi
            # Vérifier que MiroFish tourne localement
            local cache="$HOME/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json"
            local src="none"
            [[ -s "$cache" ]] && src=$(jq -r \
                '.services.ai_company.mirofish.source // "none"' \
                "$cache" 2>/dev/null || echo "none")
            if [[ "$src" != "local" ]]; then
                echo "⚠️  MiroFish n'est pas actif localement (source=$src)."
                echo "   Lancez d'abord : astrosystemctl local start mirofish"
                return 1
            fi
            echo "🐟 Alimentation du RAG MiroFish..."
            bash "$feed_script"
            ;;

        # ── Gestion du partage constellation (DRAGON_PRIVATE_SERVICES) ───────
        share)
            # Partager un service avec la constellation (retirer de DRAGON_PRIVATE_SERVICES)
            [[ -z "$service" ]] && {
                echo "Usage: astrosystemctl local share <service>"
                echo "  ex:  astrosystemctl local share ollama"
                return 1
            }
            echo "🌐 Partage de '${service}' avec la constellation..."
            _env_set_private "$service" "remove"
            ;;

        hide)
            # Rendre un service privé (ajouter à DRAGON_PRIVATE_SERVICES)
            [[ -z "$service" ]] && {
                echo "Usage: astrosystemctl local hide <service>"
                echo "  ex:  astrosystemctl local hide ollama"
                return 1
            }
            echo "🔒 Service '${service}' marqué privé (non partagé au swarm)..."
            _env_set_private "$service" "add"
            ;;

        priv|private|privé)
            # Afficher la liste des services privés actuels
            local priv
            priv=$(_priv_list)
            if [[ -z "$priv" ]]; then
                echo "  Aucun service privé — tous les services actifs sont partagés."
            else
                echo "  Services privés (non partagés) : ${priv}"
            fi
            echo ""
            echo "  Rendre privé  : astrosystemctl local hide <service>"
            echo "  Rendre public : astrosystemctl local share <service>"
            ;;

        *)
            echo "Usage: astrosystemctl local [list|start|stop|install|uninstall|feed|share|hide|priv] [service]"
            return 1
            ;;
    esac
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
    local)          cmd_local       "$@" ;;
    help|--help|-h)
        cat << 'HELP'
astrosystemctl — Cloud P2P de Puissance Astroport

Usage: astrosystemctl <commande> [service[@node]]

Commandes :
  list                      Services locaux + Power-Score de cette station
  list-remote [service]     Services GPU disponibles dans le swarm
  connect  <svc[@node]>     Connecte au meilleur nœud pour ce service
  enable   <svc[@node]>     Tunnel persistant (watchdog 20h12)
  disable  <service>        Retire de la surveillance automatique
  status                    Tunnels actifs + persistants + Power-Score
  local [list|start|stop|install|uninstall|feed] [service]
                            Panneau de contrôle des services IA locaux

Power-Score = GPU×4 + CPU×2 + RAM×0.5
  0-10  🌿 Light   → consommateur (utilise le swarm)
  11-40 ⚡ Standard → peut héberger de petits modèles localement
  41+   🔥 Brain    → fournisseur GPU pour la constellation

Exemples P2P (swarm) :
  astrosystemctl list-remote                # Qui a un GPU dans l'essaim ?
  astrosystemctl connect ollama             # Meilleur nœud ollama automatique
  astrosystemctl connect comfyui@12D3Koo…  # Nœud spécifique
  astrosystemctl enable ollama              # Watchdog: tunnel toujours actif
  astrosystemctl disable ollama             # Arrêt du watchdog

Exemples local (services IA + partage constellation) :
  astrosystemctl local                      # Tableau de bord services IA
  astrosystemctl local start ollama         # Démarrer Ollama
  astrosystemctl local stop  ollama         # Arrêter Ollama
  astrosystemctl local install              # Installer la stack IA (docker)
  astrosystemctl local install ollama       # Installer Ollama seul
  astrosystemctl local uninstall ollama     # Désinstaller (arrêt + suppression container)
  astrosystemctl local uninstall dify --purge  # Désinstaller + supprimer volumes/données
  astrosystemctl local feed                 # Alimenter MiroFish (RAG NOSTR)
  astrosystemctl local hide  ollama         # Rendre Ollama privé (non partagé)
  astrosystemctl local share ollama         # Repartager Ollama avec la constellation
  astrosystemctl local priv                 # Voir les services privés actuels

Partage constellation (DRAGON_PRIVATE_SERVICES dans .env) :
  Par défaut, tout service actif est proposé via DRAGON_p2p_ssh.sh.
  hide  → ajoute le service à DRAGON_PRIVATE_SERVICES (exclu du swarm)
  share → retire de DRAGON_PRIVATE_SERVICES (partagé de nouveau)
  Nécessite de relancer DRAGON_p2p_ssh.sh pour prise en compte.

Tunnels persistants : ~/.zen/tunnels/enabled/
Logs tunnels       : ~/.zen/tmp/tunnel.log
HELP
        ;;
    *)
        echo "Commande inconnue : '$COMMAND'. Utilisez : astrosystemctl --help"
        exit 1
        ;;
esac
