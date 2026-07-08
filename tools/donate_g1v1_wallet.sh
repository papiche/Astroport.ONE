#!/bin/bash
################################################################################
# donate_g1v1_wallet.sh — Don d'un ancien portefeuille Ğ1 "v1" (Cesium) à la
# coopérative UPlanet. Vide le solde vers DEST_G1PUB (UPLANETNAME_G1) si le
# portefeuille n'appartient pas déjà à la coopérative (primal != UPLANETNAME_G1).
#
# SÉCURITÉ — ne reçoit JAMAIS de login/password en argument (visibles par tous
# les utilisateurs du système via `ps aux`). CREDFILE est un chemin vers un
# fichier JSON {"salt":"<login>","password":"<password>"} déjà écrit par
# l'appelant (0600, /dev/shm) — supprimé par ce script en sortie, quoi qu'il
# arrive (trap), même si l'appelant le supprime aussi de son côté.
#
# Ordre des opérations — à respecter côté appelant (UPassport routers/identity.py) :
#   1. Vérification adhésion OpenCollective (avant tout).
#   2. Création du MULTIPASS (clé aléatoire, indépendante de ce don).
#   3. SEULEMENT SI le MULTIPASS a été créé avec succès : ce script (le don).
#   4. SEULEMENT SI ce script réussit (`donated:true`) : crédit ẐEN
#      (UPLANET.official.sh -l <email> -m <credited_zen>).
# Ne jamais inverser 2 et 3 : si la création du MULTIPASS échouait après un
# don déjà effectué, l'utilisateur perdrait son solde Ğ1 sans contrepartie.
#
# Usage: donate_g1v1_wallet.sh CREDFILE DEST_G1PUB [COMMENT]
################################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
. "${MY_PATH}/my.sh"

CREDFILE="$1"
DEST_G1PUB="$2"
COMMENT="${3:-UPLANET:DON_LEGACY}"

_fail() {
    echo "❌ $2" >&2
    echo "{\"donated\":false,\"error\":\"$1\"}"
    exit 1
}

[[ -z "$CREDFILE" || ! -s "$CREDFILE" ]] && _fail "MISSING_CREDFILE" "Fichier credentials manquant ou vide"
[[ -z "$DEST_G1PUB" ]] && _fail "MISSING_DEST" "Destination (DEST_G1PUB) manquante"

# Nettoyage garanti du fichier credentials en sortie, quel que soit le chemin.
trap 'rm -f "$CREDFILE"' EXIT INT TERM

LOGIN=$(jq -r '.salt // empty' "$CREDFILE" 2>/dev/null)
PASSWORD=$(jq -r '.password // empty' "$CREDFILE" 2>/dev/null)
[[ -z "$LOGIN" || -z "$PASSWORD" ]] && _fail "INVALID_CREDFILE" "Format credentials invalide (attendu: JSON {salt,password})"

## ── Dérivation de la clé v1 (scrypt login/password) ─────────────────────────
## Fichier temporaire dédié à keygen, en RAM, jamais en argument de commande.
_KEYGEN_CRED="/dev/shm/.g1v1_$$_$(date +%s%N 2>/dev/null || echo $RANDOM)"
printf '%s\n%s\n' "$LOGIN" "$PASSWORD" > "$_KEYGEN_CRED"
chmod 600 "$_KEYGEN_CRED"
V1PUB=$("${MY_PATH}/keygen" -t duniter -i "$_KEYGEN_CRED" 2>/dev/null)
rm -f "$_KEYGEN_CRED"
[[ -z "$V1PUB" ]] && _fail "V1_DERIVATION_FAILED" "Dérivation de la clé Ğ1 v1 échouée"

## Conversion SS58 (v2) — G1primal.sh/G1balance.sh/PAYforSURE.sh interrogent
## le squid GraphQL / RPC gcli Duniter v2s, natifs en adresses SS58.
SS58PUB=$(python3 "${MY_PATH}/g1pub_to_ss58.py" "$V1PUB" 2>/dev/null)
[[ -z "$SS58PUB" ]] && _fail "SS58_CONVERSION_FAILED" "Conversion SS58 échouée pour $V1PUB"

## ── Contrôle de la primo-transaction ─────────────────────────────────────────
## Refuse (cas rare) si ce wallet appartient déjà à la coopérative — les
## MULTIPASS n'exposent jamais leur salt/pepper à l'utilisateur, ce cas ne
## devrait quasiment jamais survenir en usage normal.
PRIMAL_JSON=$("${MY_PATH}/G1primal.sh" --json "$SS58PUB" 2>/dev/null)
PRIMAL=$(echo "$PRIMAL_JSON" | jq -r '.primal_source_pubkey // empty' 2>/dev/null)
if [[ -n "$PRIMAL" && "$PRIMAL" == "$UPLANETNAME_G1" ]]; then
    echo "🔴 ERREUR: $SS58PUB (dérivé de $LOGIN) appartient déjà à la coopérative (primal=$PRIMAL) — don refusé" >&2
    _fail "ALREADY_COOPERATIVE_WALLET" "Ce portefeuille appartient déjà à la coopérative"
fi

## ── Solde — ATTENTION : G1balance.sh renvoie des CENTIMES sans --convert ────
## Ne jamais diviser directement par le taux (10 Ğ1 = 1 Ẑ) sans être passé par
## des Ğ1 entiers au préalable (bug classique : /100 oublié → crédit x100 trop faible).
BALANCE_JSON=$("${MY_PATH}/G1balance.sh" "$SS58PUB" 2>/dev/null)
TOTAL_CENTIMES=$(echo "$BALANCE_JSON" | jq -r '.balances.total // 0' 2>/dev/null)
[[ -z "$TOTAL_CENTIMES" || ! "$TOTAL_CENTIMES" =~ ^-?[0-9]+$ ]] && TOTAL_CENTIMES=0
TOTAL_G1=$(echo "scale=2; ${TOTAL_CENTIMES} / 100" | bc)

if (( $(echo "${TOTAL_G1} < 1.01" | bc -l) )); then
    _fail "WALLET_EMPTY_OR_ALREADY_DONATED" "Ce portefeuille est vide ou a déjà été donné (solde: ${TOTAL_G1} Ğ1)"
fi

## ── DRAIN vers la banque centrale coopérative ────────────────────────────────
## PAYforSURE.sh accepte directement un fichier JSON {"salt","password"}.
_DRAIN_CREDFILE="/dev/shm/.g1v1drain_$$_$(date +%s%N 2>/dev/null || echo $RANDOM)"
printf '{"salt":"%s","password":"%s"}' "$LOGIN" "$PASSWORD" > "$_DRAIN_CREDFILE"
chmod 600 "$_DRAIN_CREDFILE"
"${MY_PATH}/PAYforSURE.sh" "$_DRAIN_CREDFILE" DRAIN "$DEST_G1PUB" "$COMMENT"
_DRAIN_RC=$?
rm -f "$_DRAIN_CREDFILE"

if [[ $_DRAIN_RC -ne 0 ]]; then
    _fail "DRAIN_FAILED" "Le transfert vers $DEST_G1PUB a échoué"
fi

## ── Crédit ẐEN — floor(total_g1 / 10), entier, jamais de centime ───────────
CREDITED_ZEN=$(echo "${TOTAL_G1} / 10" | bc)

echo "✅ Don reçu : ${TOTAL_G1} Ğ1 depuis ${SS58PUB} → ${DEST_G1PUB} (crédit ${CREDITED_ZEN} Ẑ)"
echo "{\"donated\":true,\"v1_pubkey\":\"${SS58PUB}\",\"balance_g1\":${TOTAL_G1},\"credited_zen\":${CREDITED_ZEN}}"
