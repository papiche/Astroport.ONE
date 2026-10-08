#shellcheck shell=bash
# specs/swarm_alerts_spec.sh — Alertes Capitaine et convention NOSTR_NSEC
#
# Couvre :
#   - RUNTIME/SWARM.newnode.alert.sh : registre des stations vues, silence au premier
#     lancement, alerte sur nouvelle machine ORIGIN, échappement HTML des valeurs
#     venant d'un pair, rejet d'un ID invalide, pas de doublon
#   - alert_captain_overlap (RUNTIME/NOSTRCARD.refresh.sh) : seuil de 50 min,
#     un seul email par jour
#   - convention "-" + NOSTR_NSEC (tools/nostr2hex.py) : même résultat que l'argument
#     direct, sans exposer la clé dans `ps`
#
# Tout se passe sous un HOME temporaire, avec un faux my.sh et un faux mailjet.sh :
# aucune donnée réelle (~/.zen) n'est lue, aucun email n'est envoyé.

Describe 'Alertes Capitaine / swarm'

  BeforeAll '_sa_setup'
  AfterAll  '_sa_teardown'

  _sa_setup() {
    SA_REPO="$(cd "$(dirname "${SHELLSPEC_SPECFILE:-$0}")/.." && pwd)"
    SA_TMP="$(mktemp -d)"
    export SA_REPO SA_TMP

    # Arborescence factice : RUNTIME/ + tools/ + templates/ à côté de HOME
    mkdir -p "$SA_TMP/RUNTIME" "$SA_TMP/tools" "$SA_TMP/templates/NOSTR" "$SA_TMP/home/.zen/tmp/swarm"
    cp "$SA_REPO/RUNTIME/SWARM.newnode.alert.sh" "$SA_TMP/RUNTIME/"
    cp "$SA_REPO/templates/NOSTR/captain_new_station.html" \
       "$SA_REPO/templates/NOSTR/captain_station_saturated.html" "$SA_TMP/templates/NOSTR/"
    printf 'IPFSNODEID=12D3KooWMyOwnStationAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\nCAPTAINEMAIL=cap@test.org\n' > "$SA_TMP/tools/my.sh"
    # Faux mailjet : journalise l'appel et conserve le corps HTML (avant-dernier argument)
    cat > "$SA_TMP/tools/mailjet.sh" <<'EOF'
#!/bin/bash
echo "$@" >> "$SA_SENT"
cp "${@: -2:1}" "$SA_SENT.html"
EOF
    chmod +x "$SA_TMP/tools/mailjet.sh"
    export SA_SENT="$SA_TMP/sent.log"

    # alert_captain_overlap extraite telle quelle du vrai script, ps simulé
    {
      echo 'log(){ echo "LOG $*"; }'
      echo 'ps(){ echo "  ${SA_FAKE_ELAPSED:-0}"; }'
      sed -n '/^alert_captain_overlap() {/,/^}/p' "$SA_REPO/RUNTIME/NOSTRCARD.refresh.sh"
    } > "$SA_TMP/overlap_fn.sh"
  }
  _sa_teardown() { rm -rf "$SA_TMP"; }

  _sa_station() {  # _sa_station <id> <json>
    mkdir -p "$SA_TMP/home/.zen/tmp/swarm/$1"
    printf '%s' "$2" > "$SA_TMP/home/.zen/tmp/swarm/$1/12345.json"
  }
  _sa_newnode() { HOME="$SA_TMP/home" bash "$SA_TMP/RUNTIME/SWARM.newnode.alert.sh"; }
  _sa_overlap() {
    HOME="$SA_TMP/home" MY_PATH="$SA_TMP/RUNTIME" CAPTAINEMAIL=cap@test.org IPFSNODEID=12D3Test \
      SA_FAKE_ELAPSED="$1" bash -c '. "$SA_TMP/overlap_fn.sh"; alert_captain_overlap 4242'
  }
  _sa_mails() { [ -f "$SA_SENT" ] && wc -l < "$SA_SENT" || echo 0; }
  _sa_reset_mail() { rm -f "$SA_SENT" "$SA_SENT.html"; }

  Describe 'SWARM.newnode.alert.sh'
    It 'reste silencieux au premier lancement (initialise le registre)'
      _sa_station 12D3KooWExistingStationBBBBBBBBBBBBBBBBBBBBBBBBBB \
        '{"ipfsnodeid":"12D3KooWExistingStationBBBBBBBBBBBBBBBBBBBBBBBBBB"}'
      _sa_reset_mail
      When call _sa_newnode
      The status should be success
      The output should equal ""
      The path "$SA_TMP/home/.zen/tmp/swarm_seen/12D3KooWExistingStationBBBBBBBBBBBBBBBBBBBBBBBBBB" should be file
      The result of function _sa_mails should equal 0
    End

    It 'alerte le Capitaine pour une nouvelle machine ORIGIN'
      _sa_station 12D3KooWNewcomerOriginCCCCCCCCCCCCCCCCCCCCCCCCCCC \
        '{"ipfsnodeid":"12D3KooWNewcomerOriginCCCCCCCCCCCCCCCCCCCCCCCCCCC","hostname":"newbox","captain":"new@captain.org","UPLANETG1PUB":"4ZqazktDxxxxxxxx","capacities":{"power_score":42}}'
      _sa_reset_mail
      When call _sa_newnode
      The status should be success
      The output should include "Alerte nouvelles machines envoyée à cap@test.org (1)"
      The result of function _sa_mails should equal 1
      The contents of file "$SA_SENT.html" should include "ORIGIN (accueil)"
      The contents of file "$SA_SENT.html" should include "new@captain.org"
    End

    It 'ne renvoie pas d alerte pour une station déjà vue'
      _sa_reset_mail
      When call _sa_newnode
      The status should be success
      The output should equal ""
      The result of function _sa_mails should equal 0
    End

    It 'échappe en HTML les valeurs venant d un pair et ignore un ID invalide'
      _sa_station 12D3KooWEvilHostnameDDDDDDDDDDDDDDDDDDDDDDDDDDDD \
        '{"ipfsnodeid":"12D3KooWEvilHostnameDDDDDDDDDDDDDDDDDDDDDDDDDDDD","hostname":"<script>alert(1)</script>&evil"}'
      _sa_station badid '{"ipfsnodeid":"../../etc/passwd"}'
      _sa_reset_mail
      When call _sa_newnode
      The status should be success
      The output should include "(1)"
      The contents of file "$SA_SENT.html" should include "&lt;script&gt;"
      The contents of file "$SA_SENT.html" should not include "<script>"
      The path "$SA_TMP/home/.zen/tmp/swarm_seen/..%2F..%2Fetc%2Fpasswd" should not be exist
    End
  End

  Describe 'alert_captain_overlap (NOSTRCARD.refresh.sh)'
    It 'ne prévient pas pour un chevauchement court (run manuel, < 50 min)'
      _sa_reset_mail
      rm -f "$SA_TMP"/home/.zen/tmp/nostrcard_overlap_alert_*
      When call _sa_overlap 600
      The status should be success
      The output should include "10 min"
      The result of function _sa_mails should equal 0
    End

    It 'prévient le Capitaine quand le cycle dépasse 50 min'
      _sa_reset_mail
      When call _sa_overlap 3900
      The status should be success
      The output should include "Alerte saturation envoyée au Capitaine cap@test.org"
      The result of function _sa_mails should equal 1
      The contents of file "$SA_SENT.html" should include "65 min"
    End

    It 'n envoie qu un seul email par jour'
      _sa_reset_mail
      When call _sa_overlap 3900
      The status should be success
      The output should not include "Alerte saturation envoyée"
      The result of function _sa_mails should equal 0
    End
  End

  Describe 'convention "-" + NOSTR_NSEC'
    _sa_have_bech32() { "${HOME_ASTRO_PY:-$HOME/.astro/bin/python3}" -c 'import bech32' 2>/dev/null \
      || python3 -c 'import bech32' 2>/dev/null; }
    _sa_py() { [ -x "$HOME/.astro/bin/python3" ] && echo "$HOME/.astro/bin/python3" || echo python3; }
    _sa_nsec() {
      "$(_sa_py)" -c 'from bech32 import bech32_encode, convertbits
print(bech32_encode("nsec", convertbits(bytes([7])*32, 8, 5)))'
    }
    _sa_hex_direct() { "$SA_REPO/tools/nostr2hex.py" "$(_sa_nsec)"; }
    _sa_hex_env()    { NOSTR_NSEC="$(_sa_nsec)" "$SA_REPO/tools/nostr2hex.py" -; }

    _sa_no_bech32() { ! _sa_have_bech32; }
    Skip if "bech32 absent" _sa_no_bech32

    It 'nostr2hex.py donne le même résultat par argument direct et par NOSTR_NSEC'
      direct=$(_sa_hex_direct)
      When call _sa_hex_env
      The status should be success
      The output should equal "$direct"
      The output should equal "0707070707070707070707070707070707070707070707070707070707070707"
    End
  End

End
