#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# SWARM.help.sh
# Guide d'utilisation du système d'essaim UPlanet
################################################################################

echo "
🌐 GUIDE DE L'ESSAIM UPlanet ♥️box
================================

💡 PRINCIPE
-----------
L'essaim UPlanet permet aux ♥️box de se connecter entre elles et de partager
leurs services spécialisés. Chaque Capitaine peut s'abonner aux services des
autres nodes et recevoir des abonnements sur son propre node.

🔍 DÉCOUVERTE
-------------
• Les nodes de l'essaim sont découverts automatiquement via le répertoire :
  ~/.zen/tmp/swarm/*/12345.json

• Chaque fichier JSON contient les informations du node :
  - Capitaine, services, coûts (PAF, NCARD, ZCARD)
  - Services spécialisés (x_*.sh) : ollama, comfyui, ssh, etc.

📝 ABONNEMENT
-------------
• Coût d'un abonnement = NCARD + ZCARD (exemple: 1 + 4 = 5 ẐEN/semaine)
• Email d'inscription spécial : capitaine+nodeid-1@domain.com
• Paiement quotidien automatique via ZEN.ECONOMY.sh

💰 PAIEMENTS
------------
• Source de paiement :
  - Node Y Level : portefeuille du node (secret.dunikey)
  - Node standard : portefeuille du capitaine
• Paiement quotidien = coût_semaine / 7 jours
• Solidarité UPlanet si fonds insuffisants

🛠️ SERVICES DISPONIBLES
-----------------------
• SSH : Accès terminal distant
• Ollama : IA locale (LLM)
• ComfyUI : Génération d'images IA
• Orpheus : Synthèse vocale
• Perplexica : Recherche IA
• Et autres selon la configuration du node

📊 FICHIERS IMPORTANTS
---------------------
• Abonnements sortants :
  ~/.zen/tmp/\$IPFSNODEID/swarm_subscriptions.json

• Abonnements reçus :
  ~/.zen/tmp/\$IPFSNODEID/swarm_subscriptions_received.json

• Découverte essaim :
  ~/.zen/tmp/swarm/*/12345.json

🔧 COMMANDES UTILES
------------------
• Découverte et abonnements :
  ~/.zen/Astroport.ONE/RUNTIME/SWARM.discover.sh

• Voir les notifications reçues :
  ~/.zen/Astroport.ONE/tools/SWARM.notifications.sh

• Cette aide :
  ~/.zen/Astroport.ONE/tools/SWARM.help.sh

⚠️ PRÉREQUIS
-----------
• Node de niveau Y (UPlanet Zen) ou UPLANETNAME='0000000000000000000000000000000000000000000000000000000000000000'
• Fonds suffisants (ZEN ou G1) pour les abonnements
• Connexion IPFS active et essaim configuré

🚀 DÉMARRAGE RAPIDE
------------------
1. Vérifiez votre niveau : cat ~/.zen/game/secret.june
2. Lancez : ~/.zen/Astroport.ONE/RUNTIME/SWARM.discover.sh
3. Choisissez un node et abonnez-vous
4. Les paiements se feront automatiquement

💡 Le système d'essaim transforme votre ♥️box en un hub de services
   connecté à tout l'écosystème UPlanet !

"

exit 0 