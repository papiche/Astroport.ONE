#!/bin/bash

# Script de test complet pour keygen
# Génère tous les types de clés à partir de salt=coucou pepper=coucou

echo "🔑 Test complet de keygen avec salt=coucou pepper=coucou"
echo "=================================================="

# Créer le répertoire de test
TEST_DIR="/tmp/keygen_test_$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "📁 Répertoire de test : $TEST_DIR"
echo ""

# Variables de test
SALT="coucou"
PEPPER="coucou"
BASE_NAME="coucou"

echo "🎯 Étape 1 : Génération du fichier .dunikey (pivot central)"
echo "--------------------------------------------------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -t duniter -o "${BASE_NAME}.dunikey" "$SALT" "$PEPPER"
echo "✅ Fichier .dunikey généré : ${BASE_NAME}.dunikey"
echo ""

echo "🔄 Étape 2 : Conversions depuis le fichier .dunikey"
echo "=================================================="

echo "📋 2.1 - Format Base58"
echo "----------------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t base58
echo ""

echo "📋 2.2 - Format Base64"
echo "----------------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t base64
echo ""

echo "📋 2.3 - Clé SSH ED25519"
echo "----------------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t ssh -o "${BASE_NAME}_ssh"
echo "✅ Clés SSH générées : ${BASE_NAME}_ssh et ${BASE_NAME}_ssh.pub"
echo ""

echo "📋 2.4 - Clé PGP"
echo "----------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t pgp -o "${BASE_NAME}_pgp"
echo "✅ Clés PGP générées : ${BASE_NAME}_pgp_private.asc et ${BASE_NAME}_pgp_public.asc"
echo ""

echo "📋 2.5 - Clé Nostr"
echo "------------------"
NOSTR_KEY=$(python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t nostr)
echo "Clé Nostr : $NOSTR_KEY"
echo "$NOSTR_KEY" > "${BASE_NAME}_nostr.txt"
echo "✅ Clé Nostr sauvegardée : ${BASE_NAME}_nostr.txt"
echo ""

echo "📋 2.6 - Adresse Bitcoin"
echo "-----------------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t bitcoin
echo ""

echo "📋 2.7 - Adresse Monero"
echo "---------------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t monero
echo ""

echo "📋 2.8 - Clés IPFS"
echo "-----------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t ipfs -o "${BASE_NAME}_ipfs"
echo "✅ Clés IPFS générées : ${BASE_NAME}_ipfs et ${BASE_NAME}_ipfs.pub"
echo ""

echo "📋 2.9 - Format JWK"
echo "-----------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t jwk -o "${BASE_NAME}_jwk.json"
echo "✅ Clé JWK générée : ${BASE_NAME}_jwk.json"
echo ""

echo "📋 2.10 - Format WIF"
echo "------------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t duniter -f wif -o "${BASE_NAME}.wif"
echo "✅ Fichier WIF généré : ${BASE_NAME}.wif"
echo ""

echo "📋 2.11 - Format EWIF (encrypté)"
echo "-------------------------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t duniter -f ewif -o "${BASE_NAME}.ewif"
echo "✅ Fichier EWIF généré : ${BASE_NAME}.ewif"
echo ""

echo "📋 2.12 - Format Seed"
echo "-------------------"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t duniter -f seed -o "${BASE_NAME}.seed"
echo "✅ Fichier Seed généré : ${BASE_NAME}.seed"
echo ""

echo "🔍 Étape 3 : Vérification des fichiers générés"
echo "============================================="
echo "Fichiers générés dans $TEST_DIR :"
ls -la
echo ""

echo "📊 Étape 4 : Résumé des conversions"
echo "==================================="
echo "✅ Fichier pivot (.dunikey) : ${BASE_NAME}.dunikey"
echo "✅ Clés SSH : ${BASE_NAME}_ssh, ${BASE_NAME}_ssh.pub"
echo "✅ Clés PGP : ${BASE_NAME}_pgp_private.asc, ${BASE_NAME}_pgp_public.asc"
echo "✅ Clé Nostr : ${BASE_NAME}_nostr.txt"
echo "✅ Clés IPFS : ${BASE_NAME}_ipfs, ${BASE_NAME}_ipfs.pub"
echo "✅ Clé JWK : ${BASE_NAME}_jwk.json"
echo "✅ Format WIF : ${BASE_NAME}.wif"
echo "✅ Format EWIF : ${BASE_NAME}.ewif"
echo "✅ Format Seed : ${BASE_NAME}.seed"
echo ""

echo "🔐 Étape 5 : Affichage du contenu du fichier .dunikey"
echo "===================================================="
echo "Contenu du fichier pivot :"
cat "${BASE_NAME}.dunikey"
echo ""

echo "📝 Étape 6 : Test de conversion inverse"
echo "======================================"
echo "Test de conversion depuis le fichier .dunikey vers différents formats :"
echo ""

echo "🔄 Test conversion .dunikey -> Base58 :"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t base58
echo ""

echo "🔄 Test conversion .dunikey -> Nostr :"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t nostr
echo ""

echo "🔄 Test conversion .dunikey -> Bitcoin :"
python3 /home/fred/workspace/AAA/Astroport.ONE/tools/keygen -i "${BASE_NAME}.dunikey" -t bitcoin
echo ""

echo "🎉 Test complet terminé !"
echo "========================"
echo "Tous les fichiers de test sont dans : $TEST_DIR"
echo "Vous pouvez examiner les fichiers générés pour vérifier les conversions."
echo ""
echo "Pour nettoyer les fichiers de test :"
echo "rm -rf $TEST_DIR"
