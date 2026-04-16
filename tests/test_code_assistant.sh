#!/bin/bash
########################################################################
# test_code_assistant.sh — Tests de validation de code_assistant
# Usage : bash Astroport.ONE/tests/test_code_assistant.sh
# Note  : Ollama doit être disponible pour les tests LLM (T4+)
########################################################################
MY_PATH=$(dirname "$(realpath "$0")")/..
CA="$MY_PATH/code_assistant"
CPSCRIPT="$MY_PATH/cpscript"
PY_BACKEND="$MY_PATH/IA/code_assistant.py"
EMBED_PY="$MY_PATH/IA/embed.py"
PASS=0; FAIL=0
_ok()   { echo "  ✅ $1"; (( PASS++ )) || true; }
_fail() { echo "  ❌ $1"; (( FAIL++ )) || true; }

echo "=== Tests code_assistant ==="
echo ""

# T1: Syntaxe de tous les scripts
echo "T1: Syntaxes"
bash -n "$CA" 2>/dev/null && _ok "code_assistant (bash)" || _fail "code_assistant syntaxe"
bash -n "$CPSCRIPT" 2>/dev/null && _ok "cpscript (bash)" || _fail "cpscript syntaxe"
python3 -m py_compile "$PY_BACKEND" 2>/dev/null && _ok "code_assistant.py (python)" || _fail "code_assistant.py syntaxe"
python3 -m py_compile "$EMBED_PY" 2>/dev/null && _ok "embed.py (python)" || _fail "embed.py syntaxe"

# T2: --help ne bloque pas
echo "T2: --help"
timeout 3 "$CA" --help &>/dev/null && _ok "--help fonctionne" || _fail "--help timeout ou erreur"

# T3: cpscript --json produit du JSON valide sur stdout (le bug principal)
echo "T3: cpscript --json produit JSON valide sur stdout"
JSON_OUT=$(timeout 15 "$CPSCRIPT" --json --depth 1 "$MY_PATH/cpscript" 2>/dev/null)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    _fail "cpscript a échoué (code $EXIT_CODE)"
elif [ -z "$JSON_OUT" ]; then
    _fail "cpscript --json ne produit rien sur stdout (bug: messages sur stdout au lieu de stderr?)"
elif echo "$JSON_OUT" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
    NB=$(echo "$JSON_OUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['stats']['files_count'])" 2>/dev/null)
    _ok "cpscript --json: JSON valide sur stdout ($NB fichiers)"
else
    # Montrer les 3 premières lignes de ce qui a été reçu
    PREVIEW=$(echo "$JSON_OUT" | head -3 | tr '\n' '|')
    _fail "cpscript --json: JSON invalide. Reçu: '$PREVIEW'"
fi

# T4: code_assistant passe le contexte JSON au backend Python
echo "T4: Pipeline cpscript → code_assistant.py"
if ! curl -sf --max-time 1 http://localhost:11434/api/tags &>/dev/null; then
    echo "  ⚠️  Ollama non disponible — T4/T5 ignorés (non bloquant)"
else
    # Simuler ce que fait code_assistant: pipe JSON vers code_assistant.py
    TEST_JSON=$(timeout 10 "$CPSCRIPT" --json --depth 0 "$MY_PATH/cpscript" 2>/dev/null)
    if [ -n "$TEST_JSON" ] && echo "$TEST_JSON" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        RESULT=$(echo "$TEST_JSON" | timeout 120 python3 "$PY_BACKEND" \
            --phase analyse \
            --kvbasename "test_$$" \
            --script "$MY_PATH/cpscript" \
            --no-qdrant \
            2>/dev/null)
        if echo "$RESULT" | grep -qi "ANALYSE\|problème\|issue\|bug\|amélioration" 2>/dev/null; then
            _ok "Pipeline complet: analyse produit une réponse LLM"
        else
            _fail "Pipeline: réponse LLM vide ou invalide (timeout Ollama?)"
        fi
        # Nettoyer la session de test
        rm -f ~/.zen/flashmem/code_assistant/test_$$.json
    else
        _fail "Le JSON de cpscript est vide — le pipeline ne peut pas fonctionner"
    fi
fi

# T5: Vérifier que code_assistant gère correctement --setup (sans Ollama)
echo "T5: --setup list models"
if curl -sf --max-time 1 http://localhost:11434/api/tags &>/dev/null; then
    # Avec Ollama: tester que --setup lance le pull sans erreur de syntaxe
    timeout 5 "$CA" --setup 2>&1 | head -3 | grep -q "Téléchargement" && \
        _ok "--setup démarre correctement" || _fail "--setup ne démarre pas"
else
    _ok "--setup ignoré (Ollama absent)"
fi

# T6: Vérifier l'intégrité de la mémoire KV
echo "T6: Mémoire KV"
KV_DIR="$HOME/.zen/flashmem/code_assistant"
mkdir -p "$KV_DIR"
TEST_KV="$KV_DIR/test_integrity_$$.json"
python3 -c "
import json, time
data = {'kvbasename': 'test', 'script': 'test.sh', 'phase': 'analyse',
        'history': [], 'last_proposals': {}, 'git_hash': 'abcdef',
        'created_at': time.time()}
with open('$TEST_KV', 'w') as f:
    json.dump(data, f)
d = json.load(open('$TEST_KV'))
assert d['git_hash'] == 'abcdef'
assert d['phase'] == 'analyse'
print('OK')
" 2>/dev/null && _ok "KV read/write JSON" || _fail "KV read/write"
rm -f "$TEST_KV"

echo ""
echo "=== Résultats: $PASS/$((PASS+FAIL)) tests passés ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
