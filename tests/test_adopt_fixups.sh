#!/bin/bash
# Test de tools/adopt_fixups.sh avec des SUBSTITUTS de tous les outils publics (did_manager, nostr_update_profile,
# nostr_follow) : on vérifie CE QUI est appelé, avec quels arguments, et que rien de secret n'apparaît en argument.
SRC="$(cd "$(dirname "$0")/.." && pwd)/tools/adopt_fixups.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT; PASS=0; FAIL=0
ok() { echo "✅ $1"; PASS=$((PASS+1)); }; ko() { echo "❌ $1"; FAIL=$((FAIL+1)); }
eq() { [[ "$1" == "$2" ]] && ok "$3" || ko "$3 (attendu « $1 », obtenu « $2 »)"; }

setup() {   # $1 = email du compte ; capitaine = cap@test.tld (distinct sauf si $2 = same)
    rm -rf "$T/tools" "$T/home" "$T/nostr" "$T/calls.log"; mkdir -p "$T/tools" "$T/home/.zen/game" "$T/nostr/$1" "$T/nostr/cap@test.tld"
    cp "$SRC" "$T/tools/adopt_fixups.sh"
    cat > "$T/tools/my.sh" <<EOS
IPFSNODEID="12D3KooWNEWSTATION"; myRELAY="ws://127.0.0.1:7777"; CAPTAINEMAIL="${2:-cap@test.tld}"
EOS
    cat > "$T/tools/did_manager_nostr.sh" <<EOS
#!/bin/bash
echo "DID \$*" >> "$T/calls.log"; exit \${STUB_DID_RC:-0}
EOS
    cat > "$T/tools/nostr_update_profile.py" <<EOS
import sys; open("$T/calls.log","a").write("PROFILE "+" ".join(sys.argv[1:])+"\n"); sys.exit(int(__import__("os").environ.get("STUB_PROFILE_RC","0")))
EOS
    cat > "$T/tools/nostr_follow.sh" <<EOS
#!/bin/bash
echo "FOLLOW src=\$1 dest=\$2 relay=\$3 NOSTR_NSEC_set=\$([[ -n \$NOSTR_NSEC ]] && echo yes || echo no) nsec_is=\${NOSTR_NSEC:0:8}" >> "$T/calls.log"; exit 0
EOS
    chmod +x "$T/tools/"*.sh
    echo "NSEC=nsec1USERSECRET; NPUB=npub1u; HEX=$(printf 'ab%.0s' {1..32})" > "$T/nostr/$1/.secret.nostr"; printf 'ab%.0s' {1..32} > "$T/nostr/$1/HEX"
    echo "NSEC=nsec1CAPSECRET0; NPUB=npub1c; HEX=$(printf 'cd%.0s' {1..32})" > "$T/nostr/cap@test.tld/.secret.nostr"; printf 'cd%.0s' {1..32} > "$T/nostr/cap@test.tld/HEX"
    echo "NSEC=nsec1NODE; NPUB=npub1n; HEX=$(printf 'ef%.0s' {1..32})" > "$T/home/.zen/game/secret.nostr"
}
run() { HOME="$T/home" ZEN_GAME_NOSTR="$T/nostr" bash "$T/tools/adopt_fixups.sh" "$1" > "$T/out.log" 2> "$T/err.log"; echo $?; }

E="user@test.tld"; setup "$E"
# le script cherche le Capitaine sous ~/.zen/game/nostr : on y pointe
mkdir -p "$T/home/.zen/game"; ln -s "$T/nostr" "$T/home/.zen/game/nostr"
eq "0" "$(run $E)" "toutes les étapes passent : code 0"
eq "12D3KooWNEWSTATION:$(printf 'ef%.0s' {1..32})" "$(cat $T/nostr/$E/home.station)" "home.station = cette station (IPFSNODEID:NODEHEX)"
grep -q "^DID update $E MULTIPASS 0 0$" "$T/calls.log" && ok "DID republié (état conservé : type MULTIPASS, montants 0)" || ko "appel DID inattendu"
P=$(grep '^PROFILE' "$T/calls.log")
echo "$P" | grep -q -- "--home_station 12D3KooWNEWSTATION:" && ok "profil : home_station publié" || ko "profil : home_station absent"
echo "$P" | grep -qE -- "--(name|about|picture|banner|website)" && ko "profil : écrase un champ de la personne ($P)" || ok "profil : AUCUN autre champ (nom, bio, photo de la personne intacts)"
grep -q "FOLLOW src=- dest=$(printf 'ab%.0s' {1..32}) .*NOSTR_NSEC_set=yes nsec_is=nsec1CAP" "$T/calls.log" && ok "le Capitaine suit le compte (clé par l'environnement)" || ko "le Capitaine ne suit pas le compte"
grep -q "FOLLOW src=- dest=$(printf 'cd%.0s' {1..32}) .*NOSTR_NSEC_set=yes nsec_is=nsec1USE" "$T/calls.log" && ok "le compte suit le Capitaine" || ko "le compte ne suit pas le Capitaine"
grep -qE "FOLLOW src=nsec1" "$T/calls.log" && ko "un nsec a été passé en ARGUMENT (visible dans ps)" || ok "aucun nsec en argument de commande"
grep -q "nsec1USERSECRET\|nsec1CAPSECRET0" "$T/out.log" "$T/err.log" && ko "un secret apparaît dans la sortie" || ok "aucun secret dans la sortie"

# échecs : jamais muets, code 2
setup "$E"; ln -s "$T/nostr" "$T/home/.zen/game/nostr"
eq "2" "$(STUB_DID_RC=1 STUB_PROFILE_RC=1 run $E)" "DID et profil en échec : code 2"
grep -q "^WARN:DID" "$T/err.log" && grep -q "^WARN:profil" "$T/err.log" && ok "chaque échec est signalé (WARN)" || ko "un échec est resté muet"

# le Capitaine EST le compte : pas de suivi de soi-même
setup "$E" "$E"; ln -s "$T/nostr" "$T/home/.zen/game/nostr"
eq "0" "$(run $E)" "compte = Capitaine : code 0"
grep -q "^FOLLOW" "$T/calls.log" && ko "le Capitaine se suit lui-même" || ok "compte = Capitaine : aucun suivi"

# compte absent : refusé
setup "$E"; rm -f "$T/nostr/$E/.secret.nostr"; ln -s "$T/nostr" "$T/home/.zen/game/nostr"
eq "1" "$(run $E)" "compte sans .secret.nostr : refusé (code 1)"
grep -q "ERROR:NO_ACCOUNT" "$T/err.log" && ok "refus explicite ERROR:NO_ACCOUNT" || ko "refus muet"

echo; echo "Passés: $PASS  Échoués: $FAIL"; [[ $FAIL -eq 0 ]]
