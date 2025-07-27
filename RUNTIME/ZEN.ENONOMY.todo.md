# ZEN.ECONOMY.evolution.md

## Feuille de Route pour l'Évolution de ZEN.ECONOMY.sh

### **Objectif : De l'Agent de Paiement au Gardien du Pacte Social**

Ce document décrit l'évolution nécessaire du script `ZEN.ECONOMY.sh` pour qu'il passe d'un simple outil de collecte de "loyers" à un véritable **gardien automatisé du pacte social et des engagements statutaires** de la SCIC CopyLaRadio.

L'objectif est d'implémenter une gouvernance par le protocole, où les règles de la coopérative ne sont pas seulement écrites dans un document légal, mais sont **exécutées de manière transparente, vérifiable et décentralisée par le code**.

### **Principes Directeurs de l'Évolution**

1.  **Alignement Statutaire :** Le script doit faire une distinction claire entre les flux de **revenus de services** (locataires) et les flux de **capital social** (sociétaires), et appliquer les droits correspondants.
2.  **Transparence Radicale :** Toutes les opérations financières doivent être non seulement traçables sur la blockchain, mais aussi compréhensibles et auditables par les membres de la coopérative.
3.  **Scalabilité Décentralisée :** L'architecture doit pouvoir supporter un réseau grandissant de nœuds (Astroports) et d'opérateurs (Capitaines, Armateurs) de manière équitable et dynamique.
4.  **Finalité Explicite :** La mission ultime de la coopérative (investissement dans des biens communs physiques comme les forêts) doit être visible et intégrée dans les flux économiques.

---

### **Évolutions Techniques Requises**

#### **1. Distinction Fondamentale : Locataire vs. Sociétaire**

*   **Besoin Statutaire :** Séparer le chiffre d'affaires des apports en capital et appliquer la gratuité des services de base aux co-propriétaires.
*   **Implémentation Technique Proposée :** Ajouter une vérification en début de boucle pour chaque utilisateur. La présence d'un "marqueur de sociétaire" (le UPassport) suspend la collecte du loyer.

    ```bash
    # Dans la boucle pour chaque utilisateur (PLAYER)
    
    # Le G1PRIME est la clé membre WoT du sociétaire, associée lors de l'inscription.
    # Cette information doit être stockée dans un fichier de configuration de l'utilisateur.
    G1PRIME=$(cat ~/.zen/game/players/$PLAYER/g1prime.key) 
    SOCIETAIRE_MARKER_FILE="~/.zen/UPassport/pdf/${G1PRIME}/N1"

    if [ -f "$SOCIETAIRE_MARKER_FILE" ]; then
        echo "$(date) - INFO: $PLAYER est un sociétaire. Loyer non applicable." >> /var/log/zen_economy.log
        continue # On passe au joueur suivant sans prélever de loyer.
    fi
    
    # ... le reste du script de collecte de loyer s'exécute ici ...
    ```

#### **2. Gestion de la Trésorerie Coopérative (Bénéfices)**

*   **Besoin Statutaire :** Centraliser les bénéfices (différence entre revenus et coûts) dans une trésorerie commune pour le réinvestissement.
*   **Implémentation Technique Proposée :** Après distribution des PAFs, calculer le surplus et le transférer vers un wallet dédié.

    ```bash
    # Après le prélèvement du LOYER et le paiement des PAFs
    
    TOTAL_PAF=$(($PAF_ARMATEUR + $PAF_CAPITAINE))
    SURPLUS=$(($LOYER - $TOTAL_PAF))

    if [ $SURPLUS -gt 0 ]; then
        dunikey -a $SURPLUS -t $SCIC_TREASURY_WALLET -p $WALLET_UPLANETNAME_G1 -m "Transfert du bénéfice locatif de $PLAYER"
        echo "$(date) - INFO: Transfert de $SURPLUS Ẑen à la trésorerie SCIC." >> /var/log/zen_economy.log
    fi
    ```

#### **3. Implémentation du Fonds d'Investissement Écologique**

*   **Besoin Statutaire :** Rendre tangible l'objectif d'acquisition de foncier.
*   **Implémentation Technique Proposée :** Une fonction (ex: cron mensuel) qui alloue une partie de la trésorerie à un portefeuille dédié.

    ```bash
    function allouer_fonds_ecologiques() {
        SCIC_TREASURY_WALLET="UPLANETNAME.TREASURY"
        FOREST_FUND_WALLET="UPLANETNAME.FOREST"
        ALLOCATION_PERCENT=50 # % décidé en AG

        treasury_balance=$(dunikey -b $SCIC_TREASURY_WALLET)
        amount_to_allocate=$(($treasury_balance * $ALLOCATION_PERCENT / 100))

        if [ $amount_to_allocate -gt 0 ]; then
            dunikey -a $amount_to_allocate -t $FOREST_FUND_WALLET -p $SCIC_TREASURY_WALLET -m "Allocation mensuelle au fonds d'investissement écologique"
            echo "$(date) - CRITICAL: Allocation de $amount_to_allocate Ẑen au fonds écologique." >> /var/log/zen_economy.log
        fi
    }
    ```

#### **4. Rémunération Dynamique des Opérateurs de Nœuds**

*   **Besoin Statutaire :** Assurer une rémunération juste et évolutive pour chaque opérateur.
*   **Implémentation Technique Proposée :** Lire un fichier de configuration pour chaque utilisateur qui définit son nœud hébergeur et les PAFs associées.

    ```bash
    # En début de boucle pour chaque utilisateur (PLAYER)

    PLAYER_NODE_CONF="~/.zen/game/players/$PLAYER/node.conf"
    if [ -f "$PLAYER_NODE_CONF" ]; then
        source "$PLAYER_NODE_CONF"
    else
        echo "$(date) - ERROR: Fichier de configuration de nœud manquant pour $PLAYER." >> /var/log/zen_economy.log
        continue
    fi

    # Le fichier node.conf contiendrait :
    # HOST_NODE_WALLET="wallet_de_larmateur_du_noeud_X"
    # CAPTAIN_WALLET="wallet_du_capitaine_du_noeud_X"
    # PAF_ARMATEUR=1
    # PAF_CAPITAINE=2
    # LOYER=4
    
    # Ces variables sont ensuite utilisées pour la distribution des paiements.
    ```

#### **5. Journal d'Audit Décentralisé et Transparent**

*   **Besoin Statutaire :** Offrir une comptabilité "liquide" et vérifiable par les sociétaires.
*   **Implémentation Technique Proposée :** Publier un résumé des opérations sur un canal NOSTR privé, accessible uniquement aux sociétaires.

    ```bash
    function publish_audit_log_to_nostr() {
        LOG_SUMMARY="Rapport économique du $(date): X loyers collectés. Y Ẑen versés aux opérateurs. Z Ẑen transférés à la trésorerie."
        
        # Utilise un outil CLI pour NOSTR, avec une clé dédiée pour le "bot comptable"
        nostril --sec $BOT_SECRET_KEY --content "$LOG_SUMMARY" --kind 1 --tag e "id_du_canal_prive_societaires"
    }
    ```

---

### **Synthèse des Évolutions Requises : Tableau Comparatif**

| Fonction Actuelle | ✅ Évolution Requise pour la Conformité Statutaire |
| :--- | :--- |
| Collecte de loyer indifférenciée | **Distingue les Locataires des Sociétaires** et applique le loyer uniquement aux premiers. |
| Distribution fixe de la PAF | **Lit une configuration par utilisateur** pour rémunérer dynamiquement le bon Armateur/Capitaine. |
| La totalité du loyer est distribuée | **Calcule le surplus (bénéfice)** et le transfère à une trésorerie centrale de la SCIC. |
| Objectifs non représentés dans le code | **Crée un "fonds écologique"** et automatise son abondement, rendant l'objectif visible on-chain. |
| Opérations silencieuses | **Génère un journal d'audit détaillé** et publie des résumés sur NOSTR pour une transparence radicale. |


### **Conclusion : L'Incarnation Technique du Pacte Social**

En implémentant ces évolutions, `ZEN.ECONOMY.sh` devient plus qu'un script. Il devient **l'incarnation technique et l'exécuteur testamentaire des statuts de la coopérative CopyLaRadio**. Il transforme les promesses légales et sociales en un protocole vivant, auditable et automatisé, qui exécute la volonté de la coopérative de manière transparente et décentralisée.