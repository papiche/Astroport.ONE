#!/bin/bash
########################################################################
# verify_upassport_health.sh
# Garde-fou après tout `pip install` dans ~/.astro : vérifie l'absence de
# conflit de dépendances (pip check) ET que UPassport (54321.py) s'importe
# réellement sans exception.
#
# Motivation (incident réel du 2026-07-28) : un `pip install` sans borne de
# version a fait sauter fastapi vers une version tirant une starlette
# incompatible (Router.__init__() rejette on_startup/on_shutdown) — resté
# invisible pendant 13h, le process déjà en mémoire ne rechargeant pas ses
# imports, jusqu'à ce qu'un redémarrage échoue. Ce script détecte ça tout de
# suite, avant que ça devienne un incident de production en pleine nuit.
#
# Usage : appelé en fin d'install.sh (non-fatal), ou manuellement après
# tout pip install/upgrade touchant ~/.astro.
########################################################################

set -uo pipefail  # pas -e : on veut voir TOUS les checks même si un échoue

ASTRO_PY="$HOME/.astro/bin/python3"
ASTRO_PIP="$HOME/.astro/bin/pip"
UPASSPORT_DIR="$HOME/.zen/UPassport"
_FAILED=0

echo "=== Vérification santé venv ~/.astro + UPassport ==="

if [[ ! -x "$ASTRO_PY" ]]; then
    echo "❌ $ASTRO_PY introuvable — venv non installé, rien à vérifier"
    exit 1
fi

echo "--- pip check (conflits de dépendances, informatif) ---"
# Informatif seulement : purement déclaratif, peut signaler des conflits
# préexistants sans casse réelle (ex: opencv/numpy) — l'import réel ci-dessous
# est le signal qui détermine le succès/échec de ce script.
if "$ASTRO_PIP" check; then
    echo "✅ Aucun conflit de dépendances"
else
    echo "⚠️  Conflits de dépendances signalés ci-dessus (à examiner, pas forcément bloquant)"
fi

echo ""
echo "--- import réel de 54321.py (UPassport) ---"
if [[ -f "$UPASSPORT_DIR/54321.py" ]]; then
    _IMPORT_RESULT=$(cd "$UPASSPORT_DIR" && timeout 30 "$ASTRO_PY" -c "
import importlib.util
spec = importlib.util.spec_from_file_location('upassport_54321', '54321.py')
mod = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(mod)
    print('OK')
except SystemExit:
    print('OK')
except Exception as e:
    print(f'FAILED: {type(e).__name__}: {e}')
" 2>&1)
    if echo "$_IMPORT_RESULT" | grep -q "^OK$"; then
        echo "✅ UPassport (54321.py) s'importe correctement"
    else
        echo "❌ UPassport (54321.py) échoue à l'import :"
        echo "$_IMPORT_RESULT"
        _FAILED=1
    fi
else
    echo "⚠️  $UPASSPORT_DIR/54321.py introuvable — vérification sautée"
fi

echo ""
if [[ $_FAILED -eq 0 ]]; then
    echo "✅ Vérification santé OK"
else
    echo "❌ Vérification santé EN ÉCHEC — corriger avant de redémarrer upassport"
fi
exit $_FAILED
