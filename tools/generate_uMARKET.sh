#!/bin/bash

# Script pour générer l'interface IPFS pour uMARKET
# Usage: ./generate_uMARKET.sh [repertoire_source]

set -e

# Fonction d'aide
show_help() {
    cat << 'HELP_EOF'
🛒 uMARKET IPFS Application Generator

USAGE:
    ./generate_uMARKET.sh [OPTIONS] DIRECTORY

ARGUMENTS:
    DIRECTORY    Répertoire source (OBLIGATOIRE) - Doit contenir un sous-répertoire 'ads/' avec les annonces en JSON.

OPTIONS:
    -h, --help   Afficher cette aide
    --log        Activer le logging détaillé (sinon sortie silencieuse)

DESCRIPTION:
    Génère une interface de marché complète pour UPlanet à partir d'annonces JSON.
    Crée une application web moderne avec recherche, filtres et affichage des produits.

EXAMPLES:
    ./generate_uMARKET.sh /path/to/market/data
    ./generate_uMARKET.sh --log /path/to/market/data

HELP_EOF
}

# Variables globales
VERBOSE=false
SOURCE_DIR=""

# Fonction de logging
log_message() {
    if [ "$VERBOSE" = true ]; then
        echo "$1" >&2
    fi
}

# Fonction d'erreur
error_message() {
    echo "$1" >&2
    exit 1
}

# Traitement des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --log)
            VERBOSE=true
            shift
            ;;
        -*)
            error_message "❌ Option inconnue: $1"
            ;;
        *)
            if [ -z "$SOURCE_DIR" ]; then
                SOURCE_DIR="$1"
            else
                error_message "❌ Trop d'arguments. Utilisez --help pour l'aide."
            fi
            shift
            ;;
    esac
done

# Validation des arguments
if [ -z "$SOURCE_DIR" ]; then
    error_message "❌ Répertoire source manquant. Utilisez --help pour l'aide."
fi

if [ ! -d "$SOURCE_DIR" ]; then
    error_message "❌ Le répertoire source n'existe pas: $SOURCE_DIR"
fi

# Vérification de la structure
if [ ! -d "$SOURCE_DIR/ads" ]; then
    error_message "❌ Le répertoire 'ads/' est manquant dans $SOURCE_DIR"
fi

# Compter les annonces JSON
AD_COUNT=$(find "$SOURCE_DIR/ads" -name "*.json" | wc -l)
if [ "$AD_COUNT" -eq 0 ]; then
    error_message "❌ Aucune annonce JSON trouvée dans $SOURCE_DIR/ads/"
fi

log_message "📊 $AD_COUNT annonces trouvées dans $SOURCE_DIR/ads/"

# Créer le répertoire public
mkdir -p "$SOURCE_DIR/public"

# Compiler toutes les annonces en un seul fichier JSON
log_message "🔄 Compilation des annonces en market.json..."

# Créer un tableau JSON avec toutes les annonces
echo '{"ads": [' > "$SOURCE_DIR/public/market.json"

# Ajouter chaque annonce
FIRST=true
while IFS= read -r -d '' file; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$SOURCE_DIR/public/market.json"
    fi
    cat "$file" >> "$SOURCE_DIR/public/market.json"
done < <(find "$SOURCE_DIR/ads" -name "*.json" -print0)

echo "]}" >> "$SOURCE_DIR/public/market.json"

log_message "✅ market.json généré avec $AD_COUNT annonces."

# Créer l'interface web moderne
log_message "🌐 Génération de l'interface web uMARKET..."

cat > "$SOURCE_DIR/_index.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🛒 uMARKET - UPlanet Marketplace</title>
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: #fff;
            min-height: 100vh;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { font-size: 3em; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.5); }
        .header p { font-size: 1.2em; opacity: 0.9; }
        .search-bar {
            width: 100%; padding: 15px; font-size: 1.1em; border: none; border-radius: 25px;
            background: rgba(255,255,255,0.1); color: #fff; margin-bottom: 30px;
            backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2);
        }
        .search-bar::placeholder { color: rgba(255,255,255,0.7); }
        .market-grid {
            display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px; margin-top: 20px;
        }
        .ad-card {
            background: rgba(255,255,255,0.1); border-radius: 15px; overflow: hidden;
            backdrop-filter: blur(10px); border: 1px solid rgba(255,255,255,0.2);
            transition: transform 0.3s ease, box-shadow 0.3s ease; cursor: pointer;
        }
        .ad-card:hover {
            transform: translateY(-5px); box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        .ad-card .image-container {
            height: 200px; background-size: cover; background-position: center;
            position: relative;
        }
        .ad-card .image-container .price-tag {
            position: absolute;
            top: 10px;
            right: 10px;
            background: rgba(0,170,255,0.9);
            color: #fff;
            padding: 5px 10px;
            border-radius: 10px;
            font-weight: bold;
        }
        .ad-card .info {
            padding: 15px;
        }
        .ad-card .info h3 {
            margin: 0 0 10px 0;
            color: #00aaff;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .ad-card .info .description {
            font-size: 0.9em;
            height: 40px;
            overflow: hidden;
            text-overflow: ellipsis;
            color: #aaa;
        }
        .ad-card .author {
            font-size: 0.8em;
            color: #777;
            padding: 10px 15px;
            border-top: 1px solid #333;
            margin-top: 10px;
            display: flex;
            align-items: center;
        }
        .author-avatar {
            width: 24px;
            height: 24px;
            border-radius: 50%;
            background: #555;
            margin-right: 10px;
        }
        /* Modal */
        .modal {
            display: none; position: fixed; z-index: 1000; left: 0; top: 0;
            width: 100%; height: 100%; overflow: auto; background-color: rgba(0,0,0,0.9);
        }
        .modal-content {
            background-color: #1e1e1e; margin: 5% auto; padding: 0;
            border: 1px solid #555; width: 80%; max-width: 800px; border-radius: 15px;
            display: flex; flex-direction: column;
        }
        .modal-images { height: 400px; background-size: contain; background-position: center; background-repeat: no-repeat; background-color: #000; border-radius: 15px 15px 0 0; }
        .modal-info { padding: 20px; }
        .modal-info h2 { color: #00aaff; }
        .modal-info .author { font-size: 1em; color: #888; margin-top: 1rem; }
        .close { color: #aaa; float: right; font-size: 28px; font-weight: bold; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛒 uMARKET</h1>
            <p>A decentralized marketplace on UPlanet</p>
        </div>
        <input type="text" id="search-input" class="search-bar" placeholder="Search for products, services, or sellers...">
        <div id="market-grid" class="market-grid"></div>
    </div>

    <div id="adModal" class="modal">
      <div class="modal-content">
        <span class="close">&times;</span>
        <div id="modal-images" class="modal-images"></div>
        <div id="modal-info" class="modal-info">
          <h2 id="modal-title"></h2>
          <p id="modal-description"></p>
          <div id="modal-author" class="author"></div>
        </div>
      </div>
    </div>

    <script>
        $(document).ready(function() {
            let allAds = [];

            function renderAds(ads) {
                const grid = $('#market-grid');
                grid.empty();
                if (ads.length === 0) {
                    grid.html('<p>No ads found.</p>');
                    return;
                }
                ads.forEach(ad => {
                    const firstImage = ad.local_images && ad.local_images.length > 0 ? '../Images/' + ad.local_images[0] : 'https://via.placeholder.com/300x200';
                    // Simple regex to find a title from the content
                    const titleMatch = ad.content.match(/^.*?(?=\n|#)/);
                    const title = titleMatch ? titleMatch[0].trim() : "Ad";

                    const card = `
                        <div class="ad-card" data-id="${ad.id}">
                            <div class="image-container" style="background-image: url('${firstImage}')">
                            </div>
                            <div class="info">
                                <h3>${title}</h3>
                                <div class="description">${ad.content.replace(/\n/g, '<br>')}</div>
                            </div>
                            <div class="author">
                                <img class="author-avatar" src="https://robohash.org/${ad.author_pubkey}?set=set4" alt="avatar">
                                <span>${ad.author_nprofile ? ad.author_nprofile.substring(0,20) : ad.author_pubkey.substring(0,20)}...</span>
                            </div>
                        </div>
                    `;
                    grid.append(card);
                });
            }

            $.getJSON('./public/market.json', function(data) {
                allAds = data.ads.sort((a,b) => b.created_at - a.created_at); // Newest first
                renderAds(allAds);
            }).fail(function() {
                $('#market-grid').html('<p style="color:red;">Error: Could not load market.json.</p>');
            });

            $('#search-input').on('input', function() {
                const searchTerm = $(this).val().toLowerCase();
                const filteredAds = allAds.filter(ad =>
                    ad.content.toLowerCase().includes(searchTerm) ||
                    (ad.author_nprofile && ad.author_nprofile.toLowerCase().includes(searchTerm))
                );
                renderAds(filteredAds);
            });
            
            // Modal logic
            const modal = $("#adModal");
            $(document).on('click', '.ad-card', function() {
                const adId = $(this).data('id');
                const ad = allAds.find(a => a.id === adId);
                if(ad) {
                    const firstImage = ad.local_images && ad.local_images.length > 0 ? '../Images/' + ad.local_images[0] : 'https://via.placeholder.com/300x200';
                    const titleMatch = ad.content.match(/^.*?(?=\n|#)/);
                    const title = titleMatch ? titleMatch[0].trim() : "Ad";

                    $('#modal-title').text(title);
                    $('#modal-description').html(ad.content.replace(/\n/g, '<br>'));
                    $('#modal-author').html(`<img class="author-avatar" src="https://robohash.org/${ad.author_pubkey}?set=set4" alt="avatar"><span>${ad.author_nprofile || ad.author_pubkey}</span>`);
                    $('#modal-images').css('background-image', `url('${firstImage}')`);
                    modal.show();
                }
            });
            $('.close').click(() => modal.hide());
            $(window).click(event => {
                if (event.target == modal[0]) {
                    modal.hide();
                }
            });

        });
    </script>
</body>
</html>
HTML_EOF

log_message "✅ _index.html pour uMARKET généré."

# Créer un index.html de redirection simple
log_message "🔄 Création du fichier index.html de redirection..."
cat > "$SOURCE_DIR/index.html" << REDIRECT_EOF
<!DOCTYPE html>
<html>
<head>
    <title>Redirecting to uMARKET</title>
    <meta http-equiv="refresh" content="0; url=./_index.html" />
</head>
<body>
    <p>If you are not redirected, <a href="./_index.html">click here</a>.</p>
</body>
</html>
REDIRECT_EOF

log_message "✅ index.html de redirection créé."

# Ajouter tout le répertoire à IPFS pour obtenir le CID final
log_message "🔗 Ajout final du répertoire complet à IPFS..."
FINAL_CID=$(ipfs add -r "$SOURCE_DIR" | tail -n1 | awk '{print $2}')

if [ -n "$FINAL_CID" ]; then
    echo "$FINAL_CID" # Sortie principale : le CID final
    log_message "✅ CID final de l'application uMARKET: $FINAL_CID"
else
    error_message "❌ Erreur lors de l'ajout final à IPFS"
fi

log_message "🎉 Application uMARKET générée avec succès!"
log_message "🌐 Accès: http://127.0.0.1:8080/ipfs/$FINAL_CID/"

exit 0 