#!/bin/bash
########################################################################
# test_cpscript.sh — Tests de validation de cpscript
# Usage : bash Astroport.ONE/tests/test_cpscript.sh
########################################################################
MY_PATH=$(dirname "$(realpath "$0")")/..
CPSCRIPT="$MY_PATH/cpscript"
PASS=0; FAIL=0

_ok()   { echo "  ✅ $1"; (( PASS++ )) || true; }
_fail() { echo "  ❌ $1"; (( FAIL++ )) || true; }
_run()  { local name="$1"; shift; "$@" && _ok "$name" || _fail "$name"; }

echo "=== Tests cpscript ==="
echo ""

# T1: Syntaxe bash correcte
echo "T1: Syntaxe bash"
bash -n "$CPSCRIPT" 2>/dev/null && _ok "syntaxe bash OK" || _fail "syntaxe bash"

# T2: --help ne bloque pas
echo "T2: --help"
timeout 3 "$CPSCRIPT" --help &>/dev/null && _ok "--help fonctionne" || _fail "--help"

# T3: Mode JSON produit du JSON valide sur stdout
echo "T3: JSON valide sur stdout (depth=1)"
JSON_OUT=$(timeout 15 "$CPSCRIPT" --json --depth 1 "$MY_PATH/cpscript" 2>/dev/null)
if echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('tool')=='cpscript'; assert len(d.get('files',[]))>0" 2>/dev/null; then
    NB=$(echo "$JSON_OUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['stats']['files_count'])" 2>/dev/null)
    _ok "JSON valide, $NB fichier(s)"
else
    _fail "JSON invalide ou timeout"
fi

# T4: --only sh produit uniquement des .sh
echo "T4: --only sh filtre correctement"
JSON_ONLY=$(timeout 15 "$CPSCRIPT" --json --depth 1 --only sh "$MY_PATH/cpscript" 2>/dev/null)
PY_COUNT=$(echo "$JSON_ONLY" | python3 -c "
import json,sys
d=json.load(sys.stdin)
py_files=[f for f in d.get('files',[]) if f['extension']=='py']
print(len(py_files))
" 2>/dev/null || echo "-1")
[ "$PY_COUNT" = "0" ] && _ok "--only sh exclut les .py" || _fail "--only sh: ${PY_COUNT} .py trouvés (attendu: 0)"

# T5: --maxfilesize tronque les fichiers volumineux
echo "T5: --maxfilesize truncation"
JSON_TRUNC=$(timeout 15 "$CPSCRIPT" --json --depth 1 --maxfilesize 100 "$MY_PATH/cpscript" 2>/dev/null)
if echo "$JSON_TRUNC" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for f in d.get('files',[]):
    if 'TRONQUÉ' in f.get('content',''):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    _ok "--maxfilesize tronque correctement (marqueur TRONQUÉ présent)"
else
    _fail "--maxfilesize : marqueur de troncation absent"
fi

# T6: Exclusion auto des répertoires build/cache
echo "T6: Exclusion auto .git/__pycache__"
# Créer un environnement de test temporaire
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/.git" "$TMP_DIR/__pycache__" "$TMP_DIR/src"
echo "#!/bin/bash" > "$TMP_DIR/main.sh"
echo "#!/bin/bash" > "$TMP_DIR/.git/hook.sh"    # ne doit pas être inclus
echo "#!/bin/bash" > "$TMP_DIR/__pycache__/cache.sh"  # ne doit pas être inclus
echo "#!/bin/bash" > "$TMP_DIR/src/helper.sh"
JSON_EXCL=$(timeout 10 "$CPSCRIPT" --json --depth 0 "$TMP_DIR/main.sh" 2>/dev/null)
GIT_COUNT=$(echo "$JSON_EXCL" | python3 -c "
import json,sys
d=json.load(sys.stdin)
git=[f for f in d.get('files',[]) if '.git' in f.get('path','') or '__pycache__' in f.get('path','')]
print(len(git))
" 2>/dev/null || echo "-1")
rm -rf "$TMP_DIR"
[ "$GIT_COUNT" = "0" ] && _ok "Exclusion .git/__pycache__ OK" || _fail "Exclusion échouée: ${GIT_COUNT} fichiers dans .git/__pycache__"

echo ""
echo "=== Résultats: $PASS/$((PASS+FAIL)) tests passés ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
