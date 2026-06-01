#!/bin/bash
################################################################################
# RUNTIME/KIN.tasks.sh — Tableau des tâches de développement auto-organisé
#
# Publie les besoins du projet sur NOSTR (Kind 30505 "objets partagés")
# afin que la communauté Kin/ATOM4LOVE puisse les prendre en charge.
#
# Chaque tâche = un "objet WoTx2" avec :
#   - Skill requis (Kind 30503 requis pour la revendiquer)
#   - Rémunération ẐEN proposée
#   - Délai estimé
#   - Contact pour la coordination
#
# Usage: ./KIN.tasks.sh [--publish] [--list] [--claim <task_id> <email>]
# Déclenché : manuellement ou dans KIN.news.sh hebdo ((( RESTAURER et relier avec todo.sh )))
################################################################################
MY_PATH="$(dirname "$0")"; MY_PATH="$(cd "$MY_PATH" && pwd)"
. "${MY_PATH}/../tools/my.sh"

TASKS_DIR="${HOME}/.zen/game/tasks"
mkdir -p "$TASKS_DIR"

STRFRY_DIR="${HOME}/.zen/strfry"
MJ="${MY_PATH}/../tools/mailjet.sh"

# ─── Tâches actuelles du projet (mise à jour manuelle) ─────────────────────
declare -A TASKS=(
    # Format : "titre|skill_requis|zen_reward|jours_estimes|description"
    ["a4l-ui-review"]="Revue UX ATOM4LOVE|ux-mobile-x1|50|7|Tester l'app sur Android, documenter les problèmes UX (screenshots + description). Retour structuré par écrit."
    ["a4l-translations"]="Traductions ATOM4LOVE|traduction-x1|30|5|Traduire les textes de l'app en occitan, breton, basque, alsacien ou autre langue régionale."
    ["astroport-docs"]="Documentation Astroport|redaction-technique-x1|40|10|Rédiger un tutorial d'installation Astroport en 10 étapes claires pour un Raspberry Pi 5."
    ["kin-template-design"]="Templates HTML newsletters Kin|html-css-x2|60|7|Améliorer le design des templates kin_daily.html et kin_birthday.html (plus lisible sur mobile)."
    ["wotx2-test"]="Test système WoTx2|mediation-x1|20|3|Créer un dossier de test Kind 1984 sur la station test, documenter le flux complet."
    ["phi-resonance-study"]="Étude résonance phi|physique-x2|80|14|Étudier et documenter mathématiquement la formule k=1/(1+sin(Δφ)) et sa pertinence pour le matching social."
    ["soundspot-setup"]="Déploiement Sound-spot|son-live-x1|40|5|Configurer un Sound-spot ZICMAMA (RPi Zero 2W) et documenter la procédure."
    ["commodat-template"]="Amélioration contrat COMMODAT|droit-x1|30|4|Réviser le template COMMODAT_ASTROPORT.md avec un juriste ou étudiant en droit."
)

# ─── Afficher les tâches disponibles ────────────────────────────────────────
list_tasks() {
    echo "======================================================================"
    echo "🔮 TABLEAU DES TÂCHES — G1FabLab / UPlanet / ATOM4LOVE"
    echo "   Rémunération en ẐEN · Prise en charge libre · WoTx2 validation"
    echo "======================================================================"
    for tid in "${!TASKS[@]}"; do
        IFS='|' read -r titre skill zen jours desc <<< "${TASKS[$tid]}"
        printf "\n  📋 [%s]\n  Titre   : %s\n  Skill   : %s\n  Récomp. : %s ẐEN\n  Délai   : %s jours\n  Desc.   : %s\n" \
            "$tid" "$titre" "$skill" "$zen" "$jours" "$desc"
    done
    echo ""
    echo "======================================================================"
    echo "Pour prendre en charge : ./KIN.tasks.sh --claim <task_id> <votre_email>"
    echo "======================================================================"
}

# ─── Publier les tâches sur NOSTR (Kind 30505 — objets WoTx2) ───────────────
publish_tasks() {
    [[ ! -x "${STRFRY_DIR}/strfry" ]] && echo "ERROR: strfry absent" >&2 && return 1
    local published=0
    for tid in "${!TASKS[@]}"; do
        IFS='|' read -r titre skill zen jours desc <<< "${TASKS[$tid]}"
        local content
        content=$(jq -n \
            --arg titre "$titre" \
            --arg desc "$desc" \
            --arg zen "$zen" \
            --arg jours "$jours" \
            '{titre:$titre, description:$desc, remuneration_zen:$zen, delai_jours:$jours,
              type:"task", status:"open", project:"atom4love/uplanet"}')
        local tags
        tags='[["d","task-'"$tid"'"],["t","uplanet-task"],["t","atom4love"],
               ["t","g1fablab"],["skill","'"$skill"'"],["quantity","1"],
               ["quantity_type","discrete"],["title","'"$titre"'"]]'
        # Publier via nostr_send_note.py si disponible
        if [[ -f "${MY_PATH}/../tools/nostr_send_note.py" ]]; then
            python3 "${MY_PATH}/../tools/nostr_send_note.py" \
                --keyfile "${HOME}/.zen/game/secret.nostr" \
                --kind 30505 \
                --content "$content" \
                --tags "$tags" 2>/dev/null && ((published++))
        fi
    done
    echo "  📡 $published tâches publiées sur NOSTR (Kind 30505)"
}

# ─── Revendiquer une tâche ──────────────────────────────────────────────────
claim_task() {
    local tid="$1" email="$2"
    [[ -z "$tid" || -z "$email" ]] && echo "Usage: --claim <task_id> <email>" && return 1
    [[ -z "${TASKS[$tid]:-}" ]] && echo "Tâche inconnue : $tid" && return 1

    IFS='|' read -r titre skill zen jours desc <<< "${TASKS[$tid]}"

    # Enregistrer la revendication localement
    local claim_file="${TASKS_DIR}/${tid}.claimed"
    echo "email=${email};date=$(date -u +%Y-%m-%d);status=claimed" > "$claim_file"

    # Notifier le Capitaine (support@qo-op.com) par email
    if [[ -x "$MJ" ]]; then
        local tmpf; tmpf=$(mktemp /tmp/task_claim_XXXXXX.html)
        cat > "$tmpf" << HTMLEOF
<!DOCTYPE html><html><head><meta charset="UTF-8"></head><body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px">
<h2 style="color:#059669">🔮 Nouvelle prise en charge de tâche — G1FabLab</h2>
<table style="width:100%;border-collapse:collapse">
<tr><td style="padding:8px;background:#f0fdf4;font-weight:700">Tâche</td><td style="padding:8px">$titre ($tid)</td></tr>
<tr><td style="padding:8px;background:#f0fdf4;font-weight:700">Contributeur</td><td style="padding:8px">$email</td></tr>
<tr><td style="padding:8px;background:#f0fdf4;font-weight:700">Skill requis</td><td style="padding:8px">$skill</td></tr>
<tr><td style="padding:8px;background:#f0fdf4;font-weight:700">Rémunération</td><td style="padding:8px">$zen ẐEN</td></tr>
<tr><td style="padding:8px;background:#f0fdf4;font-weight:700">Délai estimé</td><td style="padding:8px">$jours jours</td></tr>
<tr><td colspan="2" style="padding:8px;background:#f0fdf4;font-weight:700">Description</td></tr>
<tr><td colspan="2" style="padding:8px">$desc</td></tr>
</table>
<p style="color:#555;font-size:13px">
Répondre à ce contributeur pour coordonner le travail.<br>
Validation via WoTx2 (Kind 1506) à la livraison.<br>
Paiement ẐEN automatique après validation.
</p>
</body></html>
HTMLEOF
        "$MJ" "support@qo-op.com" "$tmpf" \
            "🔮 Tâche prise en charge : $titre par $email" 2>/dev/null
        rm -f "$tmpf"
    fi

    echo ""
    echo "  ✅ Tâche [$tid] revendiquée par $email"
    echo "  📋 Titre    : $titre"
    echo "  🎯 Skill    : $skill"
    echo "  💰 Récomp.  : $zen ẐEN à la livraison"
    echo "  📅 Délai    : $jours jours"
    echo "  📧 Coordination : support@qo-op.com"
    echo ""
}

# ─── Inclure les tâches dans la newsletter hebdo Kin ───────────────────────
tasks_for_newsletter() {
    local html=""
    html+='<div style="background:#f0fdf4;border-radius:10px;padding:1rem;margin:1rem 0">'
    html+='<div style="font-weight:700;color:#059669;margin-bottom:.6rem">🔮 Contribuer au projet G1FabLab</div>'
    html+='<div style="font-size:.82rem;color:#555;margin-bottom:.8rem">Ces tâches sont ouvertes à la communauté. Rémunération en ẐEN à la livraison.</div>'
    for tid in "${!TASKS[@]}"; do
        IFS='|' read -r titre skill zen jours desc <<< "${TASKS[$tid]}"
        html+="<div style='margin:.3rem 0;padding:.4rem .7rem;background:#fff;border-radius:6px;font-size:.8rem'>"
        html+="<strong style='color:#059669'>$titre</strong> — $zen ẐEN · $jours j<br>"
        html+="<span style='color:#6b7280'>Skill : $skill</span>"
        html+="</div>"
    done
    html+='<div style="text-align:center;margin-top:.7rem">'
    html+='<a href="mailto:support@qo-op.com?subject=Tâche%20G1FabLab" '
    html+='style="background:#059669;color:#fff;padding:.4rem 1rem;border-radius:8px;text-decoration:none;font-size:.82rem">'
    html+='✋ Je veux contribuer</a></div></div>'
    echo "$html"
}

# ─── Main ───────────────────────────────────────────────────────────────────
case "${1:-}" in
    --list)    list_tasks ;;
    --publish) publish_tasks ;;
    --claim)   claim_task "$2" "$3" ;;
    --html)    tasks_for_newsletter ;;
    *)
        echo "Usage: $0 [--list | --publish | --claim <id> <email> | --html]"
        echo "  --list    : Lister les tâches disponibles"
        echo "  --publish : Publier les tâches sur NOSTR (Kind 30505)"
        echo "  --claim   : Revendiquer une tâche"
        echo "  --html    : Générer le bloc HTML pour les newsletters"
        list_tasks
        ;;
esac
