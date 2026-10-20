#!/bin/bash
# Règle : toute clé du MULTIPASS dérivée d'un (SALT, PEPPER) l'est avec le crédentiel ISOLÉ par UPlanet
# (SALT, PEPPER_<sel UPlanet>). Teste les helpers de tools/my.sh sur des identifiants synthétiques
# (aucun compte réel) et garde les scripts qui créent/régénèrent ces clés contre un retour au pepper brut.
# EXCEPTION VOULUE : ZenCard (VISA.new.sh…) — crédentiel brut, identique sur toutes les UPlanets (CAPEX).
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$SCRIPT_DIR/tools/my.sh" >/dev/null 2>&1
K="$SCRIPT_DIR/tools/keygen"; PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }
ko() { echo "❌ $1"; FAIL=$((FAIL+1)); }
eq() { [[ "$1" == "$2" ]] && ok "$3" || ko "$3 (attendu « $1 », obtenu « $2 »)"; }
ne() { [[ "$1" != "$2" ]] && ok "$3" || ko "$3 (valeurs identiques)"; }

SALT="testsalt$$"; PEPPER="testpepper$$"
pub() { local f; f=$(uplanet_cred_file "$SALT" "$PEPPER" "$2"); case "$1" in
    g1) python3 "$SCRIPT_DIR/tools/g1pub_to_ss58.py" "$($K -t duniter -i "$f")";;
    nostr) python3 "$SCRIPT_DIR/tools/nostr2hex.py" "$($K -t nostr -i "$f")";;
    ipns) python3 "$SCRIPT_DIR/tools/peerid2ipns.py" "$($K -t ipfs -i "$f")";; esac; rm -f "$f"; }

# ── isolation entre UPlanets : même (SALT, PEPPER), UPlanets différentes → clés différentes
UPLANETNAME="uplanet-A"; A_G1=$(pub g1 isolated); A_IPNS=$(pub ipns isolated); A_SALT=$(uplanet_salt)
UPLANETNAME="uplanet-B"; B_G1=$(pub g1 isolated); B_IPNS=$(pub ipns isolated); B_SALT=$(uplanet_salt)
ne "$A_SALT" "$B_SALT" "sel UPlanet différent pour deux UPLANETNAME"
ne "$A_G1" "$B_G1"     "wallet Ğ1 isolé : différent d'une UPlanet à l'autre"
ne "$A_IPNS" "$B_IPNS" "clé IPNS isolée : différente d'une UPlanet à l'autre"
UPLANETNAME="uplanet-A"
L_G1=$(pub g1 legacy)
ne "$A_G1" "$L_G1" "formule legacy (pepper brut) ≠ formule isolée"
eq "${PEPPER}_${A_SALT}" "$(uplanet_pepper "$PEPPER")" "uplanet_pepper = PEPPER_<sel> (isolée par défaut)"
eq "$PEPPER" "$(uplanet_pepper "$PEPPER" legacy)"      "uplanet_pepper legacy = pepper brut"

# ── resolve_key_formula : retrouve la formule qui a créé la référence, refuse sinon
for kind in g1 nostr ipns; do
    eq "isolated" "$(resolve_key_formula $kind "$SALT" "$PEPPER" "$(pub $kind isolated)")" "resolve $kind : référence isolée → isolated"
    eq "legacy"   "$(resolve_key_formula $kind "$SALT" "$PEPPER" "$(pub $kind legacy)")"   "resolve $kind : référence legacy → legacy"
    resolve_key_formula $kind "$SALT" "$PEPPER" "reference-fausse" >/dev/null && ko "resolve $kind : accepte une fausse référence" || ok "resolve $kind : refuse une fausse référence"
done
eq "isolated" "$(resolve_key_formula ipns "$SALT" "$PEPPER" "/ipns/$(pub ipns isolated)")" "resolve ipns : accepte le préfixe /ipns/"
# Même (SALT,PEPPER) mais autre UPlanet : la référence isolée de A n'est PAS reproduite sous B (ni en legacy)
UPLANETNAME="uplanet-B"; resolve_key_formula g1 "$SALT" "$PEPPER" "$A_G1" >/dev/null && ko "wallet d'une autre UPlanet accepté" || ok "wallet d'une autre UPlanet refusé (pas de chevauchement)"
UPLANETNAME="uplanet-A"

# ── derive_account_keys : écrit tout avec la bonne formule, refuse (sans rien écrire) sinon
T=$(mktemp -d)
derive_account_keys "$T" "$SALT" "$PEPPER" "$(pub nostr legacy)" "$(pub g1 isolated)" "$(pub ipns isolated)" 2>/dev/null \
    && ok "derive_account_keys : formules mixtes (nostr legacy, g1/ipns isolées) reproduites" || ko "derive_account_keys : échec sur des références valides"
eq "nostr=legacy g1=isolated ipns=isolated" "$(cat "$T/.keyformula" 2>/dev/null)" "derive_account_keys : .keyformula"
eq "$(pub g1 isolated)" "$(cat "$T/G1PUBNOSTR" 2>/dev/null)" "derive_account_keys : G1PUBNOSTR en SS58"
eq "/ipns/$(pub ipns isolated)" "$(cat "$T/NOSTRNS" 2>/dev/null)" "derive_account_keys : NOSTRNS"
[[ "$(stat -c %a "$T/.secret.nostr" 2>/dev/null)" == "600" ]] && ok "derive_account_keys : .secret.* en 0600" || ko "droits .secret.nostr"
rm -rf "$T"; T=$(mktemp -d)
derive_account_keys "$T" "$SALT" "$PEPPER" "$(pub nostr legacy)" "$(pub g1 isolated)" "k51-mauvais-nostrns" 2>/dev/null \
    && ko "derive_account_keys accepte un NOSTRNS faux" || ok "derive_account_keys refuse un NOSTRNS faux"
eq "0" "$(ls -A "$T" | wc -l)" "derive_account_keys : rien écrit en cas de refus"; rm -rf "$T"

# ── API d'un compte déjà créé : account_key_formula / account_cred_file / .keyformula
export ZEN_GAME_NOSTR=$(mktemp -d); E="acct@test.tld"; D="$ZEN_GAME_NOSTR/$E"; mkdir -p "$D"
echo "/?salt=${SALT}&nostr=${PEPPER}" > "$D/.secret.disco"
echo "$(pub nostr legacy)" > "$D/HEX"; echo "$(pub g1 isolated)" > "$D/G1PUBNOSTR"; echo "/ipns/$(pub ipns isolated)" > "$D/NOSTRNS"
eq "legacy"   "$(account_key_formula "$E" nostr)" "account_key_formula nostr : retrouvée par le HEX (compte historique)"
eq "isolated" "$(account_key_formula "$E" g1)"    "account_key_formula g1 : retrouvée par G1PUBNOSTR"
eq "isolated" "$(account_key_formula "$E" ipns)"  "account_key_formula ipns : retrouvée par le NOSTRNS"
eq "nostr=legacy g1=isolated ipns=isolated" "$(cat "$D/.keyformula")" ".keyformula mis en cache, une entrée par clé"
echo "$(pub g1 legacy)" > "$D/G1PUBNOSTR"            # le cache prime : plus de recalcul
eq "isolated" "$(account_key_formula "$E" g1)" "account_key_formula : le cache .keyformula prime"
c=$(account_cred_file "$E" nostr); eq "$(pub nostr legacy)" "$(python3 "$SCRIPT_DIR/tools/nostr2hex.py" "$($K -t nostr -i "$c")")" "account_cred_file nostr : redonne la clé NOSTR du compte"; rm -f "$c"
_keyformula_set "$D" g1 legacy; eq "nostr=legacy g1=legacy ipns=isolated" "$(cat "$D/.keyformula")" "_keyformula_set : met à jour une clé, conserve les autres"
rm -f "$D/.keyformula" "$D/.secret.disco"
account_key_formula "$E" nostr >/dev/null 2>&1 && ko "account_key_formula sans .secret.disco : doit échouer" || ok "account_key_formula sans .secret.disco : échoue (erreur visible)"
echo "/?salt=${SALT}&nostr=${PEPPER}" > "$D/.secret.disco"; echo "0000" > "$D/HEX"
account_key_formula "$E" nostr >/dev/null 2>&1 && ko "account_key_formula : accepte une référence fausse" || ok "account_key_formula : refuse une référence fausse (jamais de clé proche)"
c=$(account_cred_file "$E" nostr 2>/dev/null) && ko "account_cred_file : renvoie un crédentiel malgré une référence fausse" || ok "account_cred_file : refuse sans formule vérifiée"
rm -rf "$ZEN_GAME_NOSTR"; unset ZEN_GAME_NOSTR
eq "isolated" "$(MULTIPASS_NOSTR_FORMULA= new_account_nostr_formula)" "nouveau compte : formule NOSTR isolée par défaut"
eq "legacy" "$(MULTIPASS_NOSTR_FORMULA=legacy new_account_nostr_formula)" "restauration explicite d'un compte historique : legacy"
eq "isolated" "$(MULTIPASS_NOSTR_FORMULA=n-importe-quoi new_account_nostr_formula)" "valeur inconnue : retombe sur isolated"

# ── garde GÉNÉRALE : aucun script ne dérive une clé de (salt, pepper) BRUTS, sauf exceptions marquées
#    ZENCARD (clé CAPEX, volontairement identique sur toutes les UPlanets) ou COOP (graine UPLANETNAME).
RAW='keygen[^|#]* -t (nostr|ipfs|duniter|bitcoin|monero)[^|#]*"\$\{?(salt|SALT)\}?"[^|#]*"\$\{?(pepper|PEPPER)\}?"'
OFFENDERS=$(cd "$SCRIPT_DIR/.." && grep -rnE "$RAW" --include=*.sh Astroport.ONE UPassport 2>/dev/null \
    | grep -v '/tests/\|keygen_test.sh' | grep -v 'ZENCARD\|COOP' | grep -vE '^[^:]+:[0-9]+:\s*#')
if [[ -z "$OFFENDERS" ]]; then ok "garde générale : aucune dérivation (salt,pepper) brute hors ZENCARD/COOP"
else ko "garde générale : dérivations brutes non marquées (utiliser my.sh : account_cred_file / uplanet_cred_file)"; echo "$OFFENDERS" | sed 's/^/     /' | cut -c1-170; fi
# make_NOSTRCARD : le crédentiel NOSTR doit venir de uplanet_cred_file, jamais d'un printf brut
if grep -nE 'printf[^>]*"\$\{SALT\}" "\$\{PEPPER\}"[^_]*>' "$SCRIPT_DIR/tools/make_NOSTRCARD.sh" >/dev/null; then ko "make_NOSTRCARD.sh : crédentiel brut écrit à la main"; else ok "make_NOSTRCARD.sh : crédentiel NOSTR via uplanet_cred_file"; fi
grep -q '_keyformula_set.*nostr' "$SCRIPT_DIR/tools/make_NOSTRCARD.sh" && ok "make_NOSTRCARD.sh : écrit .keyformula" || ko "make_NOSTRCARD.sh : n'écrit pas .keyformula"

echo; echo "Passés: $PASS  Échoués: $FAIL"; [[ $FAIL -eq 0 ]]
