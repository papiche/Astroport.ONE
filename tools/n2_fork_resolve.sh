#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
#~ n2_fork_resolve.sh — gel de compte Ğ1-N² et résolution après rencontre humaine
#~
#~ Quand une double dépense est PROUVÉE (deux transactions signées, même `prev`), la station
#~ gèle le compte de l'auteur (aucune tx sortante acceptée) et prévient les concernés et le
#~ capitaine. Le gel ne se lève que par décision humaine : les personnes concernées se
#~ rencontrent, établissent quelle transaction est la bonne, et le capitaine l'enregistre ici.
#~
#~ Usage :
#~   n2_fork_resolve.sh list                       comptes gelés
#~   n2_fork_resolve.sh show    <hex>              preuve (les deux évènements signés)
#~   n2_fork_resolve.sh resolve <hex> <event_id>   <event_id> = la transaction VALIDE ;
#~                                                 l'autre est annulée sur CETTE station,
#~                                                 le compte est dégelé, soldes recalculés
#~
#~ Décision locale (monnaie relative) : chaque station applique la décision de SON capitaine ;
#~ les capitaines des cercles concernés doivent prendre la même.
#~ Après résolution, relancer la synchro (backfill_constellation.sh --days N) pour importer la
#~ branche valide si elle avait été rejetée ici.
################################################################################
LIB="${N2_LEDGER_LIB:-$HOME/.zen/workspace/NIP-101/relay.writePolicy.plugin/filter/n2_ledger_lib.sh}"
[[ -s "$LIB" ]] || { echo "n2_ledger_lib.sh introuvable ($LIB)" >&2; exit 1; }
source "$LIB"
INCIDENTS="${N2_INCIDENTS_FILE:-$HOME/.zen/strfry/n2_incidents.jsonl}"

cmd="${1:-}"; hex="${2:-}"; valid="${3:-}"
case "$cmd" in
  list)
    [[ -s "$N2_FROZEN_FILE" ]] || { echo "Aucun compte gelé."; exit 0; }
    while IFS=: read -r h prev ts e1 e2; do
        echo "${h}  gelé le $(date -d "@$ts" '+%F %T')  prev=${prev:0:12}…  évènements: ${e1:0:12}… / ${e2:0:12}…"
    done < "$N2_FROZEN_FILE" ;;
  show)
    n2_is_frozen "$hex" || { echo "Compte non gelé : $hex" >&2; exit 1; }
    IFS=: read -r _ prev ts e1 e2 < <(grep "^${hex}:" "$N2_FROZEN_FILE" | head -1)
    for e in "$e1" "$e2"; do
        echo "── $e"
        (cd "$N2_STRFRY_DIR" && ./strfry scan "{\"ids\":[\"$e\"]}" 2>/dev/null) | jq -c '{id,created_at,dest:(.tags[]|select(.[0]=="p")|.[1]),amount:(.tags[]|select(.[0]=="amount")|.[1])}' \
            || true
    done
    echo "(un évènement absent de ce store = branche rejetée ici, reçue d'un pair)" ;;
  resolve)
    [[ "$hex" =~ ^[0-9a-f]{64}$ && "$valid" =~ ^[0-9a-f]{64}$ ]] || { echo "Usage: $0 resolve <hex> <event_id valide>" >&2; exit 1; }
    n2_is_frozen "$hex" || { echo "Compte non gelé : $hex" >&2; exit 1; }
    IFS=: read -r _ prev ts e1 e2 < <(grep "^${hex}:" "$N2_FROZEN_FILE" | head -1)
    if   [[ "$valid" == "$e1" ]]; then other="$e2"
    elif [[ "$valid" == "$e2" ]]; then other="$e1"
    else echo "L'évènement valide doit être $e1 ou $e2" >&2; exit 1; fi
    # destinataires de la branche annulée (si présente dans le store) : leur solde doit être recalculé
    dests=$( (cd "$N2_STRFRY_DIR" && ./strfry scan "{\"ids\":[\"$other\"]}" 2>/dev/null) | jq -r '.tags[]|select(.[0]=="p")|.[1]' 2>/dev/null)
    mkdir -p "$(dirname "$N2_VOID_FILE")"; echo "$other" >> "$N2_VOID_FILE"
    n2_unfreeze "$hex"
    for pk in "$hex" $dests; do n2_ledger_rescan_author "$pk" >/dev/null 2>&1; done
    jq -cn --arg ts "$(date -Iseconds)" --arg a "$hex" --arg ok "$valid" --arg ko "$other" \
        '{ts:$ts,type:"fork_resolved",author:$a,valid:$ok,void:$ko}' >> "$INCIDENTS"
    echo "✅ ${hex:0:12}… dégelé. Valide: ${valid:0:12}…  Annulée (cette station): ${other:0:12}…"
    echo "→ relancez la synchro pour importer la branche valide si elle manque ici :"
    echo "   ~/.zen/workspace/NIP-101/backfill_constellation.sh --days 7" ;;
  *) sed -n '/^#~ Usage/,/^#~ Décision/p' "$0" | sed 's/^#~ \{0,1\}//'; exit 1 ;;
esac
