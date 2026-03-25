Cette analyse approfondie décortique l'architecture logicielle d'Astroport.ONE et du réseau UPlanet ẐEN. Le système repose sur une symbiose entre la **Monnaie Libre (Ğ1)**, le protocole social **Nostr** et le stockage décentralisé **IPFS**.

# 📋 RÔLES DES SCRIPTS UPLANET ẐEN

## 🎯 **ARCHITECTURE COMPLÈTE ET SPÉCIALISÉE**

L'écosystème est divisé en quatre couches fonctionnelles : l'Identité, l'Économie, la Maintenance (20h12) et le Swarm (l'Essaim).

---

### 👤 1. GESTION DE L'IDENTITÉ : MULTIPASS vs ZEN CARD

Le système distingue l'usage (le locataire) de la propriété (le sociétaire).

*   **`VISA.new.sh` (La Forge d'Identité) :** 
    *   **Rôle :** Génère de manière déterministe (via Salt/Pepper) un trousseau triple : **Duniter** (Wallet Ğ1), **Nostr** (Clés sociales) et **IPFS** (ID de stockage).
    *   **Lien :** Il crée le lien entre l'email de l'utilisateur et sa position géographique (UMAP).
*   **`NOSTRCARD.refresh.sh` (Gestionnaire MULTIPASS) :**
    *   **MULTIPASS :** C'est l'identité "Usage/Social". Elle permet d'accéder au uDRIVE et aux services.
    *   **Rôle Économique :** Gère le prélèvement hebdomadaire du loyer (**NCARD**, ex: 1 Ẑen) reversé au Capitaine.
    *   **Automatisation :** Met à jour le profil Nostr et republie le coffre-fort IPNS.
*   **`PLAYER.refresh.sh` (Gestionnaire ZEN CARD) :**
    *   **ZEN Card :** C'est l'identité "Capital/Coopérative". Elle représente les parts sociales du noeud.
    *   **U.SOCIETY :** Gère les abonnements longue durée (SATELLITE/CONSTELLATION). Si un membre est `U.SOCIETY`, il est exempté des prélèvements hebdomadaires car il a déjà contribué au capital.
    *   **Protection :** Empêche la suppression (UNPLUG) du capitaine même en cas de solde nul.
*   **`Ylevel.sh` (Synchronisation de sécurité) :**
    *   Élève le niveau de sécurité en liant la clé SSH de la machine physique à l'identité IPFS et Duniter. C'est ce qui transforme un simple utilisateur en **Armateur** (propriétaire du matériel).

---

### 💰 2. LE MOTEUR ÉCONOMIQUE (ẐEN ECONOMY)

L'économie est basée sur le ratio **1 Ẑen = 0.1 Ğ1**. Le système automatise la fiscalité et la redistribution.

*   **`PAYforSURE.sh` (Le Moteur de Transaction) :**
    *   Le script le plus critique pour les échanges. Il utilise `g1cli` pour envoyer des Ğ1 sur Duniter v2s.
    *   **Intelligence :** Il gère les "retries" sur plusieurs nœuds du réseau en cas de panne et génère un rapport HTML envoyé par email.
*   **`primal_wallet_control.sh` (Le Radar Anti-Intrusion) :**
    *   **Concept de Source Primale :** Vérifie que chaque Ğ1 entrant dans un wallet MULTIPASS provient bien d'une source autorisée (le noeud ou la banque centrale UPlanet).
    *   **Sécurité :** Si un Ğ1 "inconnu" entre (tentative d'intrusion ou don non tracé), le script redirige automatiquement les fonds vers le wallet `UPLANETNAME_INTRUSION`.
*   **`ZEN.ECONOMY.sh` (Le Distributeur de Bénéfices) :**
    *   Applique la règle constitutionnelle des **3x1/3 + 1%** :
        1.  **33% Trésorerie (CASH) :** Pour le fonctionnement.
        2.  **33% R&D :** Pour le développement du code.
        3.  **33% Assets (Patrimoine) :** Pour racheter du matériel.
        4.  **1% Parrain :** Prime pour celui qui a fait entrer le membre.
*   **`oc2uplanet.sh` (Le Pont Financier) :**
    *   Scanne les dons sur OpenCollective (Euros) et les convertit en Ẑen sur les ZEN Cards locales. C'est l'interface entre l'économie traditionnelle et l'économie circulaire Ẑen.

---

### 👨‍✈️ 3. GESTION DU CAPITAINE ET DU SYSTÈME

Le Capitaine est l'opérateur humain de la station.

*   **`dashboard.sh` (La Console de Commandement) :**
    *   Interface interactive qui résume la santé économique (soldes des wallets système) et technique (services actifs).
    *   Permet au capitaine d'effectuer des actions rapides : redémarrer les services, imprimer des identités ou gérer les sociétaires.
*   **`heartbox_analysis.sh` (Le Diagnostic Rapide) :**
    *   Analyse en quelques secondes l'espace disque, la charge CPU et la disponibilité des ports.
    *   **Slots :** Calcule combien de nouveaux MULTIPASS (10Go) ou ZEN Cards (128Go) la station peut encore accueillir.
*   **`20h12.process.sh` (Le Majordome de Maintenance) :**
    *   Tâche Cron quotidienne qui exécute la "Solar Calibration" (calcul de l'heure selon la position du soleil).
    *   Met à jour tous les dépôts Git (Astroport, UPassport, G1Billet).
    *   Relance les tunnels de support P2P (Dragons).

---

### 🌐 4. LE SWARM (L'ESSAIM) ET RÉSEAU

Astroport n'est pas un serveur isolé, c'est un noeud d'une constellation.

*   **`_12345.sh` (Le Cœur du Noeud) :**
    *   Maintient la "Balise IPNS" de la station. Il publie toutes les heures un fichier `12345.json` contenant les coordonnées du noeud.
    *   **Synchronisation :** C'est lui qui va chercher les cartes des autres stations chez les "Bootstraps" pour construire la carte mondiale du réseau.
*   **`backfill_constellation.sh` (Le Synchroniseur d'Histoire) :**
    *   Parcourt les autres relais Nostr de la constellation pour récupérer les messages manqués.
    *   Assure que si une station tombe, les autres conservent les données sociales (N² Memory).
*   **`did_manager_nostr.sh` (Le Registre d'Identité Décentralisé) :**
    *   Utilise Nostr (Kind 30800) comme source de vérité pour les métadonnées d'identité.
    *   Gère la conformité "France Connect" pour les identités vérifiées.
*   **`DRAGON_p2p_ssh.sh` (Le Bouclier des Dragons) :**
    *   Ouvre des accès sécurisés à travers IPFS. Cela permet au support technique ("Les Dragons") d'intervenir sur une machine même derrière un pare-feu ou une box 4G sans IP publique.

---

### 🛠 5. OUTILS DATA ET MULTIMÉDIA

*   **`ajouter_media.sh` :** L'outil principal pour l'utilisateur. Il permet d'importer des vidéos YouTube (via `yt-dlp`), des PDF ou des MP3, de les ajouter à IPFS, et de publier automatiquement la métadonnée sur Nostr (NIP-94).
*   **`generate_ipfs_structure.sh` :** Génère dynamiquement une interface web (uDRIVE) pour chaque utilisateur, permettant de naviguer dans ses fichiers IPFS comme dans un explorateur de fichiers classique.
*   **`power_monitor.sh` :** Surveille la consommation électrique (Watts) de la station pour permettre, à terme, la facturation au coût énergétique réel.

---

## 💡 **RÉSUMÉ DES FLUX ÉCONOMIQUES**

1.  **Le Locataire (MULTIPASS)** paie 1 Ẑen/semaine via `NOSTRCARD.refresh.sh`.
2.  **Le Capitaine** reçoit ce Ẑen sur son wallet business (`uplanet.captain.dunikey`).
3.  **La SCIC (UPlanet)** prélève une part via `ZEN.ECONOMY.sh` pour l'infrastructure et la R&D.
4.  **L'Armateur (Propriétaire)** voit la valeur de son matériel protégée par le fonds de roulement accumulé sur les wallets de capital.
5.  **L'Intrus** qui tente d'injecter de l'argent non tracé est neutralisé par `primal_wallet_control.sh`.