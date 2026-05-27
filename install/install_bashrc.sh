#!/bin/bash
########################################################################
# install_bashrc.sh — Mise à jour idempotente du bloc ASTROPORT dans ~/.bashrc
#
# Idempotent : peut être relancé à chaque upgrade.
# Remplace le bloc existant s'il est présent, l'ajoute sinon.
# Extrait de install/setup/setup.sh pour être réutilisable indépendamment.
# Appelé par : setup.sh (premier install) et install.sh (upgrade).
# License: AGPL-3.0
########################################################################

BASHRC="$HOME/.bashrc"
START_MARK="# >>> ASTROPORT BLOCK >>>"
END_MARK="# <<< ASTROPORT BLOCK <<<"

echo "########################### Updating ♥BOX ~/.bashrc"

TMP_FILE=$(mktemp)
cat > "$TMP_FILE" <<'BASHRC_CONTENT'
# >>> ASTROPORT BLOCK >>>

export PATH=$HOME/.local/bin:/usr/games:$PATH

## Activer le venv Python .astro
if [[ -s "$HOME/.astro/bin/activate" ]]; then
    . "$HOME/.astro/bin/activate"
else
    export PATH="$HOME/.astro/bin:$PATH"
fi

source $HOME/.zen/Astroport.ONE/tools/my.sh 2>/dev/null

echo "⚓ Astroport Node Ready. Type 'station-info' for details."

# <<< ASTROPORT BLOCK <<<
BASHRC_CONTENT

## Remplace le bloc existant ou l'ajoute à la fin
if grep -q "$START_MARK" "$BASHRC" 2>/dev/null; then
    echo ">>> Existing ASTROPORT block found → updating"
    sed -i "/$START_MARK/,/$END_MARK/d" "$BASHRC"
else
    echo ">>> No existing block → adding"
fi
cat "$TMP_FILE" >> "$BASHRC"
rm -f "$TMP_FILE"

## Recharger dans la session courante (best-effort, no-op si non-interactive)
# shellcheck disable=SC1090
source "$BASHRC" 2>/dev/null || true

echo "<<< ~/.bashrc updated — PATH=$PATH"
