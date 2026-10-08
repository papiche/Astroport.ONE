#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# SWARM.newnode.alert.sh
# Informe le Capitaine des nouvelles machines apparues dans le swarm
# (~/.zen/tmp/swarm/*/12345.json), typiquement des Astroport en mode ORIGIN
# (espace d'accueil, swarm.key à zéros) qui demandent à rejoindre la constellation.
# Une fois machine + capitaine évalués, le Capitaine transmet la swarm.key ẐEN
# (le nouvel arrivant lance zen_join.beta.sh pour passer de ORIGIN à ẐEN).
#
# Appelé par _12345.sh après chaque scan du swarm. Idempotent : un registre
# ~/.zen/tmp/swarm_seen/<IPFSNODEID> évite de notifier deux fois la même station.
# Premier lancement : le registre est initialisé silencieusement avec les stations
# déjà présentes (pas de rafale d'emails sur une station existante).
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/../tools/my.sh"

SWARM_DIR="$HOME/.zen/tmp/swarm"
SEEN_DIR="$HOME/.zen/tmp/swarm_seen"
[[ -d "$SWARM_DIR" ]] || exit 0
FIRST_RUN=false
[[ -d "$SEEN_DIR" ]] || FIRST_RUN=true
mkdir -p "$SEEN_DIR"

NEW_JSONS=()
for json in "$SWARM_DIR"/*/12345.json; do
    [[ -s "$json" ]] || continue
    node_id=$(jq -r '.ipfsnodeid // empty' "$json" 2>/dev/null)
    # Un ID de station est un PeerID IPFS : charset strict (sert aussi de nom de fichier)
    [[ "$node_id" =~ ^[A-Za-z0-9]{20,80}$ ]] || continue
    [[ "$node_id" == "$IPFSNODEID" ]] && continue
    [[ -e "$SEEN_DIR/$node_id" ]] && continue
    date +%s > "$SEEN_DIR/$node_id"
    [[ "$FIRST_RUN" == "true" ]] && continue
    NEW_JSONS+=("$json")
done

[[ ${#NEW_JSONS[@]} -eq 0 || -z "$CAPTAINEMAIL" ]] && exit 0

# Les 12345.json viennent de pairs non fiables : toute valeur est échappée avant
# d'être insérée dans le HTML (rendu en Python, pas de substitution sed/bash).
TMPF=$(mktemp)
python3 - "${MY_PATH}/../templates/NOSTR/captain_new_station.html" "$IPFSNODEID" "${#NEW_JSONS[@]}" "${NEW_JSONS[@]}" > "$TMPF" <<'PY'
import sys, json, html
tpl_path, me, count, *files = sys.argv[1:]
def e(v, n=120):
    return html.escape(str(v if v not in (None, "") else "?")[:n])
rows = []
for f in files:
    try:
        d = json.load(open(f))
    except Exception:
        continue
    pub = str(d.get("UPLANETG1PUB") or "")
    mode = "ORIGIN (accueil)" if pub.startswith("4ZqazktD") else "autre UPlanet"
    cap = d.get("capacities") or {}
    svc = d.get("dragon_services") or d.get("services") or ""
    if isinstance(svc, (list, dict)):
        svc = ", ".join(map(str, svc))
    rows.append(
        "<div class='card'><table>"
        f"<tr><td>Machine</td><td><strong>{e(d.get('hostname'))}</strong></td></tr>"
        f"<tr><td>IPFSNODEID</td><td><code>{e(d.get('ipfsnodeid'), 80)}</code></td></tr>"
        f"<tr><td>Capitaine</td><td>{e(d.get('captain'))}</td></tr>"
        f"<tr><td>Mode</td><td><strong>{e(mode)}</strong></td></tr>"
        f"<tr><td>Localisation</td><td>{e(d.get('IPCity'))}</td></tr>"
        f"<tr><td>Power-Score</td><td>{e(cap.get('power_score'))}</td></tr>"
        f"<tr><td>Services partagés</td><td>{e(svc, 200)}</td></tr>"
        f"<tr><td>Version</td><td>{e(d.get('version'))}</td></tr>"
        "</table></div>")
tpl = open(tpl_path).read()
for k, v in (("_ROWS_", "".join(rows)), ("_COUNT_", count), ("_STATION_", html.escape(me))):
    tpl = tpl.replace(k, v)
print(tpl)
PY

timeout 60 "${MY_PATH}/../tools/mailjet.sh" --channel alerts \
    --template "${MY_PATH}/../templates/NOSTR/captain_new_station.html" \
    --expire 7d "${CAPTAINEMAIL}" "$TMPF" "🛰️ ${#NEW_JSONS[@]} nouvelle(s) machine(s) détectée(s) dans le swarm" \
    && echo "Alerte nouvelles machines envoyée à ${CAPTAINEMAIL} (${#NEW_JSONS[@]})" \
    || echo "⚠️ Envoi de l'alerte nouvelles machines échoué"
rm -f "$TMPF"
