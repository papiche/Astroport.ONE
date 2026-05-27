#!/bin/bash
## INSTALL UPassport — idempotent (install + upgrade)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
[[ -s "$HOME/.astro/bin/activate" ]] && . "$HOME/.astro/bin/activate"
. "${MY_PATH}/../tools/my.sh"

echo "📦 UPassport API — installation/mise à jour (http://localhost:54321)"

if [[ ! -d ~/.zen/UPassport ]]; then
    mkdir -p ~/.zen
    cd ~/.zen
    git clone --depth 1 https://github.com/papiche/UPassport.git
    cd UPassport
    ~/.astro/bin/pip install -U -r requirements.txt
    ./setup_systemd.sh
    [[ ! -f .env ]] && cat > .env <<EOL
myDUNITER="https://g1.cgeek.fr"
myCESIUM="https://g1.data.e-is.pro"
EOL
    echo "✅ UPassport installé"
    cat .env
    cd -
else
    ## UPGRADE : git pull + pip update + systemd reload
    echo "🔄 UPassport déjà présent — mise à jour..."
    cd ~/.zen/UPassport
    git pull --ff-only 2>/dev/null \
        && echo "  ✅ Code mis à jour (git pull)" \
        || echo "  ⚠️  git pull échoué (dépôt modifié localement ?)"
    ~/.astro/bin/pip install -U -r requirements.txt 2>/dev/null \
        && echo "  ✅ Dépendances Python mises à jour" \
        || echo "  ⚠️  pip install -U échoué"
    ## Recharger systemd si le service existe
    ./setup_systemd.sh 2>/dev/null || true
    cd -
fi

exit 0
