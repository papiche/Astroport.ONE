#shellcheck shell=bash
# specs/respawn_nostrcard_spec.sh — Tests pour tools/respawn_NOSTRCARD.sh
#
# Couvre : détection d'un compte legacy vs moderne (respawn_nostrcard_helper.py),
# récupération du DISCO (.secret.disco > .multipass.json > CLI), garde-fou de
# sécurité (un SALT/PEPPER erroné ne doit jamais matcher une identité existante),
# et le comportement du CLI (--help, --check, --scan-all, --dry-run, erreurs).
#
# Tous les comptes utilisés sont des fixtures isolées sous un HOME temporaire :
# aucune donnée réelle (~/.zen) n'est lue ni modifiée par ces tests.

Describe 'respawn_NOSTRCARD.sh'

  BeforeAll '_rnc_spec_setup'
  AfterAll  '_rnc_spec_teardown'

  _rnc_spec_setup() {
    TOOLS_PATH="$(cd "$(dirname "${SHELLSPEC_SPECFILE:-$0}")/../tools" && pwd)"
    export TOOLS_PATH

    RNC_TEST_HOME="$(mktemp -d)"
    export RNC_TEST_HOME
    export HOME="${RNC_TEST_HOME}"

    # ── Compte "legacy" : uniquement le socle fondateur ──────────────────
    mkdir -p "${RNC_TEST_HOME}/.zen/game/nostr/legacy@test.com"
    cat > "${RNC_TEST_HOME}/.zen/game/nostr/legacy@test.com/.secret.nostr" <<'EOF'
NSEC=nsec1fake; NPUB=npub1fake; HEX=abc123
EOF
    echo "G1fakepubkey" > "${RNC_TEST_HOME}/.zen/game/nostr/legacy@test.com/G1PUBNOSTR"

    # ── Compte "moderne" : tous les artefacts Tier1/Tier2 présents ───────
    MODERN_DIR="${RNC_TEST_HOME}/.zen/game/nostr/modern@test.com"
    mkdir -p "${MODERN_DIR}/identity" "${MODERN_DIR}/APP/uDRIVE"
    cp "${RNC_TEST_HOME}/.zen/game/nostr/legacy@test.com/.secret.nostr" "${MODERN_DIR}/.secret.nostr"
    cp "${RNC_TEST_HOME}/.zen/game/nostr/legacy@test.com/G1PUBNOSTR" "${MODERN_DIR}/G1PUBNOSTR"
    for f in .pass LANG HEX NPUB home.station TODATE ZUMAP GPS did.json.cache \
             .secret.disco .multipass.json BITCOIN MONERO .ssss.head.player.enc \
             .ssss.mid.captain.enc ssss.tail.uplanet.enc .ssss.player.key NOSTRNS \
             uSPOT.QR.png IPNS.QR.png ._SSSSQR.png MULTIPASS.QR.png MULTIPASS.QR.png.cid \
             PROFILE.QR.png .nostr.zine.html; do
        echo "x" > "${MODERN_DIR}/${f}"
    done
    for f in .Core.md .Style.md .Rules.md .Preferences.md .Objectifs.md; do
        echo "x" > "${MODERN_DIR}/identity/${f}"
    done
    echo "x" > "${MODERN_DIR}/APP/uDRIVE/index.html"

    # ── Compte sans identité fondatrice (pas un MULTIPASS exploitable) ───
    mkdir -p "${RNC_TEST_HOME}/.zen/game/nostr/notanaccount@test.com"

    # ── Compte avec DISCO recouvrable (.secret.disco) ────────────────────
    mkdir -p "${RNC_TEST_HOME}/.zen/game/nostr/discotest@test.com"
    echo "/?salt=abc123&nostr=def456" > "${RNC_TEST_HOME}/.zen/game/nostr/discotest@test.com/.secret.disco"

    # ── Compte avec DISCO recouvrable uniquement via .multipass.json ────
    mkdir -p "${RNC_TEST_HOME}/.zen/game/nostr/jsondisco@test.com"
    cat > "${RNC_TEST_HOME}/.zen/game/nostr/jsondisco@test.com/.multipass.json" <<'EOF'
{"salt": "jsonsalt", "pepper": "jsonpepper"}
EOF

    # ── Compte avec identité NOSTR réelle dérivée (pour le garde-fou) ────
    CRED="$(mktemp)"
    printf '%s\n%s\n' "realsalt" "realpepper" > "${CRED}"
    REAL_NPUB="$("${TOOLS_PATH}/keygen" -t nostr -i "${CRED}")"
    REAL_HEX="$("${TOOLS_PATH}/nostr2hex.py" "${REAL_NPUB}")"
    rm -f "${CRED}"
    export REAL_NPUB REAL_HEX
    mkdir -p "${RNC_TEST_HOME}/.zen/game/nostr/verify@test.com"
    cat > "${RNC_TEST_HOME}/.zen/game/nostr/verify@test.com/.secret.nostr" <<EOF
NSEC=nsec1fake; NPUB=${REAL_NPUB}; HEX=${REAL_HEX}
EOF

    # shellcheck source=/dev/null
    . "${TOOLS_PATH}/respawn_nostrcard_lib.sh"
  }

  _rnc_spec_teardown() {
    rm -rf "${RNC_TEST_HOME}"
  }

  # ══════════════════════════════════════════════════════════════════════
  Describe 'respawn_nostrcard_helper.py audit'

    It 'détecte un compte legacy (Tier1/Tier2 manquants)'
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" audit legacy@test.com
      The status should be success
      The output should include '"legacy": true'
      The output should include '".pass"'
      The output should include '".secret.disco"'
    End

    It 'reconnaît un compte moderne comme conforme'
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" audit modern@test.com
      The status should be success
      The output should include '"legacy": false'
      The output should include '"tier1_missing": []'
      The output should include '"tier2_missing": []'
    End

    It "refuse un répertoire sans identité fondatrice (.secret.nostr absent)"
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" audit notanaccount@test.com
      The status should be success
      The output should include '"is_multipass": false'
      The output should include 'MISSING_FOUNDATIONAL_IDENTITY'
    End

    It 'scan-all recense le compte legacy et pas le moderne'
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" scan-all
      The status should be success
      The output should include 'legacy@test.com'
    End

    It "scan-all n'inclut PAS le compte moderne dans legacy_emails"
      When run bash -c "python3 '${TOOLS_PATH}/respawn_nostrcard_helper.py' scan-all | jq -e '.legacy_emails == [\"legacy@test.com\"]' >/dev/null"
      The status should be success
    End
  End

  # ══════════════════════════════════════════════════════════════════════
  Describe 'respawn_nostrcard_helper.py recover-disco'

    It 'récupère SALT/PEPPER depuis .secret.disco en priorité'
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" recover-disco discotest@test.com
      The status should be success
      The output should include '"salt": "abc123"'
      The output should include '"pepper": "def456"'
      The output should include '"source": ".secret.disco"'
    End

    It 'retombe sur .multipass.json si .secret.disco est absent'
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" recover-disco jsondisco@test.com
      The status should be success
      The output should include '"salt": "jsonsalt"'
      The output should include '"pepper": "jsonpepper"'
      The output should include '"source": ".multipass.json"'
    End

    It 'accepte un SALT/PEPPER fourni en CLI si aucune source locale'
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" recover-disco nodisco@test.com --salt manualsalt --pepper manualpepper
      The status should be success
      The output should include '"source": "cli-arguments"'
    End

    It "échoue proprement si aucun DISCO n'est recouvrable"
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" recover-disco nodisco@test.com
      The status should be failure
      The output should include 'DISCO_NOT_RECOVERABLE'
    End
  End

  # ══════════════════════════════════════════════════════════════════════
  Describe 'respawn_nostrcard_helper.py verify-identity (garde-fou de sécurité)'

    It 'confirme la correspondance quand le SALT/PEPPER est correct'
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" verify-identity verify@test.com --salt realsalt --pepper realpepper
      The status should be success
      The output should include '"match": true'
    End

    It "refuse quand le SALT/PEPPER ne reproduit PAS l'identité existante"
      When run python3 "${TOOLS_PATH}/respawn_nostrcard_helper.py" verify-identity verify@test.com --salt wrong --pepper wrong
      The status should be failure
      The output should include '"match": false'
    End
  End

  # ══════════════════════════════════════════════════════════════════════
  Describe 'respawn_nostrcard_lib.sh rnc_verify_duniter_pub (garde-fou Tier2/ZenCard)'

    It 'confirme une clé Duniter re-dérivée correctement'
      REAL_DUNITER_V1="$("${TOOLS_PATH}/keygen" -t duniter -i <(printf 'dsalt\ndpepper\n'))"
      When call rnc_verify_duniter_pub "dsalt" "dpepper" "${REAL_DUNITER_V1}" ""
      The status should be success
    End

    It 'rejette un SALT/PEPPER qui ne reproduit pas la clé existante'
      REAL_DUNITER_V1="$("${TOOLS_PATH}/keygen" -t duniter -i <(printf 'dsalt\ndpepper\n'))"
      When call rnc_verify_duniter_pub "dsalt" "WRONG_PEPPER" "${REAL_DUNITER_V1}" ""
      The status should be failure
      The stderr should include "ne correspond PAS"
    End
  End

  # ══════════════════════════════════════════════════════════════════════
  Describe 'respawn_NOSTRCARD.sh (CLI)'

    # Le sourcing inconditionnel de my.sh (avant même le parsing des options)
    # émet du bruit stderr sans rapport avec ce script dès que ~/.zen ne
    # ressemble pas à une vraie station (dunikeys absents, etc.) — attendu
    # dans ce HOME de test isolé. On l'ignore volontairement (2>/dev/null)
    # sauf dans les deux tests qui vérifient explicitement un message stderr
    # propre à respawn_NOSTRCARD.sh (où le bruit peut cohabiter, "include"
    # reste vrai).
    It "affiche l'aide avec --help"
      When run bash -c "'${TOOLS_PATH}/respawn_NOSTRCARD.sh' --help 2>/dev/null"
      The status should be failure
      The output should include 'Usage: respawn_NOSTRCARD.sh'
      The output should include '--scan-all'
    End

    It "refuse un email au format invalide"
      When run "${TOOLS_PATH}/respawn_NOSTRCARD.sh" "not-an-email"
      The status should be failure
      The stderr should include "Format d'email invalide"
    End

    It "signale l'absence de MULTIPASS local pour un email inconnu"
      When run "${TOOLS_PATH}/respawn_NOSTRCARD.sh" "ghost@test.com"
      The status should be failure
      The stderr should include "Aucun MULTIPASS local"
      The output should include "make_NOSTRCARD.sh"
    End

    It '--check renvoie un statut d-echec (1) pour un compte legacy'
      When run bash -c "'${TOOLS_PATH}/respawn_NOSTRCARD.sh' --check legacy@test.com 2>/dev/null"
      The status should be failure
      The output should include 'LEGACY'
    End

    It '--check renvoie un succes (0) pour un compte moderne'
      When run bash -c "'${TOOLS_PATH}/respawn_NOSTRCARD.sh' --check modern@test.com 2>/dev/null"
      The status should be success
      The output should include 'conforme'
    End

    It '--scan-all liste le compte legacy sans rien modifier'
      When run bash -c "'${TOOLS_PATH}/respawn_NOSTRCARD.sh' --scan-all 2>/dev/null"
      The status should be success
      The output should include 'legacy@test.com'
      The output should include 'Comptes legacy   : 1'
    End

    It "--dry-run n'écrit aucun fichier (Tier 1)"
      When run bash -c "'${TOOLS_PATH}/respawn_NOSTRCARD.sh' legacy@test.com --dry-run --yes 2>/dev/null"
      The status should be success
      The output should include '[dry-run]'
      The path "${RNC_TEST_HOME}/.zen/game/nostr/legacy@test.com/.pass" should not be exist
      The path "${RNC_TEST_HOME}/.zen/game/nostr/legacy@test.com/home.station" should not be exist
    End

  End

End
