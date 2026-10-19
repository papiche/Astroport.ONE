#!/bin/bash
################################################################################
# node_activity_watch.sh — détection de problèmes à partir de node-activity.jsonl
#
#   Source  : ~/.zen/tmp/$IPFSNODEID/observability/node-activity.jsonl (LOCAL, non publié)
#   Sorties :
#     - ~/.zen/tmp/$IPFSNODEID/activity_summary.json : agrégat SANS IP ni identifiant
#       (publié avec la balise IPNS, lisible par l'essaim)
#     - email au capitaine si un couple (script, category) dépasse un seuil d'échecs
#       sur la fenêtre, avec cooldown par clé (pas de spam).
#
#   Seuils (surchargeables par l'environnement) :
#     NAW_WINDOW_H=1  NAW_MIN_FAILS=10  NAW_MIN_RATE=50 (%)  NAW_COOLDOWN_H=6
#
#   Appelé par _12345.sh à chaque cycle. Échoue silencieusement.
################################################################################
MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IPFSNODEID="${IPFSNODEID:-$(jq -r '.Identity.PeerID // empty' "$HOME/.ipfs/config" 2>/dev/null)}"
[[ -z "$IPFSNODEID" ]] && exit 0

NODE_DIR="$HOME/.zen/tmp/${IPFSNODEID}"
ACTIVITY="$NODE_DIR/observability/node-activity.jsonl"
SUMMARY="$NODE_DIR/activity_summary.json"
STATE="$HOME/.zen/flashmem/node_activity_alerts.json"
[[ -s "$ACTIVITY" ]] || exit 0
mkdir -p "$HOME/.zen/flashmem" "$NODE_DIR" 2>/dev/null

ALERTS=$(python3 - "$ACTIVITY" "$SUMMARY" "$STATE" \
    "${NAW_WINDOW_H:-1}" "${NAW_MIN_FAILS:-10}" "${NAW_MIN_RATE:-50}" "${NAW_COOLDOWN_H:-6}" <<'PYEOF' 2>/dev/null
import sys, json, time, os

activity, summary_path, state_path, window_h, min_fails, min_rate, cooldown_h = sys.argv[1:8]
window_h, min_fails, min_rate, cooldown_h = float(window_h), int(min_fails), float(min_rate), float(cooldown_h)
now = time.time()
cutoff = time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(now - window_h * 3600))

stats = {}
with open(activity, encoding="utf-8") as f:
    for line in f:
        try:
            e = json.loads(line)
        except Exception:
            continue
        if e.get("timestamp", "") < cutoff:
            continue
        key = (e.get("script", "?"), e.get("category", ""))
        s = stats.setdefault(key, {"total": 0, "failures": 0})
        s["total"] += 1
        if not e.get("success"):
            s["failures"] += 1

try:
    with open(state_path, encoding="utf-8") as f:
        state = json.load(f)
except Exception:
    state = {}

alerts = []
for (script, category), s in stats.items():
    rate = 100.0 * s["failures"] / s["total"] if s["total"] else 0
    if s["failures"] >= min_fails and rate >= min_rate:
        k = f"{script}|{category}"
        if now - state.get(k, 0) >= cooldown_h * 3600:
            alerts.append({"script": script, "category": category, **s, "rate": round(rate)})
            state[k] = now

by_key = [{"script": k[0], "category": k[1], **v} for k, v in sorted(stats.items(), key=lambda x: -x[1]["failures"])]
out = {
    "generated": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
    "window_h": window_h,
    "total": sum(v["total"] for v in stats.values()),
    "failures": sum(v["failures"] for v in stats.values()),
    "by_key": by_key[:20],
}
tmp = summary_path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False)
os.replace(tmp, summary_path)
if alerts:
    with open(state_path, "w", encoding="utf-8") as f:
        json.dump(state, f)
for a in alerts:
    print(f"{a['script']} / {a['category'] or '-'} : {a['failures']}/{a['total']} échecs ({a['rate']}%) sur {window_h:g}h")
PYEOF
)

if [[ -n "$ALERTS" && -n "${CAPTAINEMAIL:-}" && -x "$MY_PATH/mailjet.sh" ]]; then
    _tmp=$(mktemp /tmp/node_activity_alert_XXXXXX.html)
    _html=$(printf '%s' "$ALERTS" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    cat > "$_tmp" <<HTML
<h2>🚨 Station $(hostname) — taux d'échec anormal</h2>
<p><strong>Date :</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
<pre style="background:#fff3cd;padding:1em;border-radius:4px;white-space:pre-wrap;">${_html}</pre>
<p>Détail : <code>~/.zen/tmp/${IPFSNODEID}/observability/node-activity.jsonl</code> (local)</p>
<hr><p style="color:#888;font-size:0.85em;">Cooldown ${NAW_COOLDOWN_H:-6}h par (script, catégorie).</p>
HTML
    bash "$MY_PATH/mailjet.sh" --template "bro_alert" --expire 48h \
        "$CAPTAINEMAIL" "$_tmp" "🚨 Taux d'échec — $(hostname)" >/dev/null 2>&1
    rm -f "$_tmp"
fi
exit 0
