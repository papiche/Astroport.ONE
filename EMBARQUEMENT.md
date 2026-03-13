# 🏴‍☠️ GUIDE D'EMBARQUEMENT UPLANET ẐEN

## 🎯 **INTRODUCTION**

Bienvenue dans l'écosystème UPlanet ẐEN ! Ce guide vous accompagne pour devenir Capitaine d'une ♥️BOX (CoeurBox) et rejoindre la coopérative des autohébergeurs.

---

## 🚀 **PROCESSUS D'EMBARQUEMENT**

### **📦 1. Installation Astroport.ONE**

```bash
# Installation automatique
bash <(wget -qO- https://raw.githubusercontent.com/papiche/Astroport.ONE/master/install.sh)
```

L'installation propose automatiquement l'embarquement UPlanet ẐEN à la fin.

### **🏴‍☠️ 2. Assistant d'Embarquement UPlanet ẐEN**

```bash
# Lancement manuel de l'assistant
~/.zen/Astroport.ONE/uplanet_onboarding.sh
```

#### **Étapes de l'assistant :**

1. **📖 Présentation** : Découverte de l'économie ẐEN et de la coopérative
2. **💰 Configuration économique** : PAF, tarifs services, fiscalité
3. **💻 Valorisation machine** : Apport au capital social (500€ à 8000€)
4. **🎯 Choix du mode** : UPlanet ORIGIN (niveau X) ou ẐEN (niveau Y)
5. **🌐 Configuration réseau** : Selon le mode choisi
6. **🏛️ Initialisation UPLANET** : Création des portefeuilles selon le mode
7. **🚀 Niveau Y** : Passage en mode autonome (ẐEN seulement)
8. **🏴‍☠️ Embarquement Capitaine** : Création de votre identité
9. **📋 Finalisation** : Résumé et prochaines étapes

---

## 🎯 **CHOIX DU MODE UPLANET**

### **🌍 UPlanet ORIGIN (Niveau X) - Mode Simplifié**

**Caractéristiques :**
- **Réseau IPFS public** standard
- **Économie UPlanet basique** sans complexité coopérative
- **Initialisation immédiate** sans prérequis réseau
- **Pas de swarm.key** nécessaire
- **Idéal pour débuter** ou tester le système

**Avantages :**
- **Simplicité** : Configuration rapide et facile
- **Accessibilité** : Aucun prérequis technique
- **Stabilité** : Réseau IPFS public fiable
- **Test** : Parfait pour découvrir UPlanet

### **🏴‍☠️ UPlanet ẐEN (Niveau Y) - Mode Coopératif**

**Caractéristiques :**
- **Réseau IPFS privé** avec swarm.key
- **Économie coopérative complète** avec gouvernance
- **Nécessite un ami capitaine** ou formation BLOOM
- **Passage au niveau Y obligatoire** pour l'autonomie
- **Production et gouvernance** décentralisée

**Avantages :**
- **Économie complète** : Tous les mécanismes ẐEN
- **Gouvernance** : Participation aux décisions
- **Réseau privé** : Sécurité et performance
- **Coopération** : Communauté de capitaines

### **🔄 Migrations et Limitations**

#### **🌍→🏴‍☠️ Passage ORIGIN → ẐEN (Possible mais destructif)**

Le passage d'ORIGIN vers ẐEN est **possible** mais **destructif** :

1. **Désinscription automatique** de tous les comptes ORIGIN
   - MULTIPASS NOSTR (via `nostr_DESTROY_TW.sh`)
   - ZEN Card PLAYER (via `PLAYER.unplug.sh`)
2. **Suppression des wallets** coopératifs ORIGIN
3. **Installation d'une swarm.key** ẐEN
4. **Passage au niveau Y** obligatoire
5. **Réinitialisation UPLANET** avec nouveau UPLANETNAME

**⚠️ Raison :** Les comptes ORIGIN proviennent de la source primale `0000000000000000000000000000000000000000000000000000000000000000`, incompatible avec la source ẐEN `$(cat ~/.ipfs/swarm.key)`.

**🔧 Outil de migration :**
```bash
# Lancer l'assistant de mise à jour
~/.zen/Astroport.ONE/update_config.sh

# Le script détecte automatiquement votre mode actuel et propose :
# - Mode ORIGIN : Option de migration vers ẐEN (avec avertissements)
# - Mode ẐEN : Mise à jour de la configuration existante
# - Installation fraîche : Configuration initiale
```

#### **🏴‍☠️→🌍 Passage ẐEN → ORIGIN (Impossible)**

**❌ INTERDIT :** Une fois en mode ẐEN, **impossible** de revenir à ORIGIN.

**Raisons techniques :**
- Comptes liés à la source primale ẐEN
- Désinscription complète trop complexe
- Risque de perte de données et de fonds

**Solution :** Réinstallation complète d'Astroport.ONE sur un OS frais.

#### **🏴‍☠️→🏴‍☠️ Changement d'UPlanet ẐEN (Impossible)**

**❌ INTERDIT :** Une fois connecté à une UPlanet ẐEN, **impossible** de changer vers une autre UPlanet.

**Raisons techniques :**
- Comptes liés à l'UPLANETNAME spécifique
- Sources primales différentes entre UPlanet
- Migration nécessiterait désinscription complète

**Solution :** Réinstallation complète d'Astroport.ONE sur un OS frais.

---

## 🔧 **ASSISTANT DE MISE À JOUR**

### **📋 `update_config.sh` - Gestionnaire de Configuration**

L'assistant de mise à jour détecte automatiquement votre mode UPlanet actuel et propose les actions appropriées.

#### **🔍 Détection Automatique**

```bash
~/.zen/Astroport.ONE/update_config.sh
```

Le script analyse votre installation et détermine :

| Mode Détecté | Critères | Actions Proposées |
|--------------|----------|-------------------|
| **🏴‍☠️ ẐEN** | `~/.ipfs/swarm.key` existe | • Mise à jour configuration<br>• Paramètres économiques<br>• **Pas de changement d'UPlanet** |
| **🌍 ORIGIN** | Comptes dans `~/.zen/game/` | • Rester en ORIGIN<br>• **Migration vers ẐEN** (destructive) |
| **🆕 Fraîche** | Aucun compte détecté | • Configuration initiale<br>• Embarquement complet |

#### **🌍 Gestion Mode ORIGIN**

Lorsque des comptes ORIGIN sont détectés :

```bash
# Affichage automatique des comptes existants
Comptes ORIGIN détectés:
   • MULTIPASS NOSTR: 3
   • ZEN Card PLAYER: 2

Options disponibles:
  1. 🔄 Rester en ORIGIN et mettre à jour la configuration
  2. 🏴‍☠️ Passer en mode ẐEN (DESTRUCTIF - désinscrit tous les comptes)
  3. ❌ Annuler
```

#### **🏴‍☠️ Migration ORIGIN → ẐEN**

**Processus sécurisé avec confirmations multiples :**

1. **Avertissement détaillé** des conséquences
2. **Confirmation explicite** (tapez "OUI")
3. **Désinscription automatique** via `nostr_DESTROY_TW.sh` et `PLAYER.unplug.sh`
4. **Lancement de l'assistant** d'embarquement ẐEN
5. **Configuration complète** du nouveau mode

#### **🔧 Options en Ligne de Commande**

```bash
# Mise à jour directe
update_config.sh --update

# Affichage configuration
update_config.sh --show

# Embarquement direct
update_config.sh --onboard

# Aide
update_config.sh --help
```

---

## ⚙️ **CONFIGURATION ÉCONOMIQUE**

### **📊 Paramètres Principaux**

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| **PAF** | Participation Aux Frais hebdomadaire | 14 Ẑen/semaine |
| **NCARD** | Tarif MULTIPASS (10Go) | 1 Ẑen/semaine |
| **ZCARD** | Tarif ZEN Card (128Go) | 4 Ẑen/semaine |
| **MACHINE_VALUE_ZEN** | Valorisation machine | 500 Ẑen |

### **💻 Types de Machines**

| Type | Valorisation | Usage recommandé |
|------|-------------|------------------|
| **🛰️ Satellite** | 500€ → 500 Ẑen | RPi, mini-PC, station légère |
| **🎮 PC Gamer** | 4000€ → 4000 Ẑen | Station intermédiaire puissante |
| **💼 Serveur Pro** | 8000€ → 8000 Ẑen | Infrastructure professionnelle |
| **🔧 Personnalisée** | Sur mesure | Valorisation adaptée |

### **📊 Détection Automatique des Capacités**

L'assistant utilise `heartbox_analysis.sh` pour :
- **Détecter automatiquement** les ressources système (CPU, RAM, disque)
- **Calculer les capacités** d'hébergement en temps réel
- **Suggérer le type de machine** optimal selon les ressources
- **Afficher les slots disponibles** pour ZEN Cards et MULTIPASS

### **📈 Modèle Économique Dynamique**

```
Capacités calculées automatiquement :
• ZEN Cards : Espace NextCloud / 128Go = X slots
• MULTIPASS : Espace IPFS / 10Go = Y slots

Revenus potentiels calculés :
• ZEN Cards : X slots × 4 Ẑen = A Ẑen/semaine
• MULTIPASS : Y slots × 1 Ẑen = B Ẑen/semaine
• Total théorique : (A + B) Ẑen/semaine

Bénéfice net : Total - PAF (14 Ẑen/semaine)
```

---

## 🌐 **CONNEXION AU RÉSEAU UPLANET ẐEN (IPFS LAN)**

### **🤝 Mode 1 : Rejoindre une UPlanet Existante (Recommandé)**

Pour rejoindre une UPlanet ẐEN existante, vous devez :

1. **Être ami avec un Capitaine** d'un relais Astroport de cette UPlanet
2. **Récupérer manuellement** le fichier `swarm.key` de cette UPlanet
3. **Placer la clé** dans votre configuration

```bash
# Exemple : Récupération depuis un capitaine ami
scp capitaine@astroport.example.com:~/.ipfs/swarm.key ~/.ipfs/swarm.key

# UPlanet ORIGIN n'a pas de swarm.key et publie sur IPFS WAN
```

**Avantages :**
- **Connexion immédiate** à un réseau actif
- **Communauté établie** avec capitaines expérimentés
- **Services disponibles** dès l'embarquement

### **🌍 Mode 2 : Création Automatique de Swarm (BLOOM.Me.sh)**

Si aucune UPlanet n'existe dans votre zone géographique :

1. **Allumer suffisamment de stations** Astroport dans la même zone (~100km)
2. **Laisser agir** le script `BLOOM.Me.sh` automatiquement
3. **Attendre la formation** d'un nouveau swarm UPlanet

```bash
# Le script BLOOM.Me.sh s'exécute automatiquement
~/.zen/Astroport.ONE/RUNTIME/BLOOM.Me.sh
```

**Conditions requises :**
- **Minimum 9 stations** Astroport de niveau Y dans la même région GPS
- **Concordance SSH/IPFS** : Chaque station doit avoir `SSH == IPFS NodeID`
- **Même zone géographique** : Coordonnées GPS arrondies identiques

**Processus automatique :**
1. **Détection des stations** : Scan des Astroports niveau Y dans la région
2. **Vérification des clés** : Concordance SSH ↔ IPFS NodeID
3. **Génération collective** : Création d'une `swarm.key` partagée
4. **Bootstrap automatique** : Liste des nœuds de démarrage
5. **Activation du swarm** : Réseau privé IPFS opérationnel

### **🏠 Mode 3 : Réseau Local/Privé**

Pour un réseau privé spécifique :

```bash
# Fournir votre propre swarm.key
cp /chemin/vers/votre/swarm.key ~/.ipfs/swarm.key
```

### **🔬 Détails Techniques BLOOM.Me.sh**

Le script `BLOOM.Me.sh` implémente un processus de consensus distribué :

#### **🎯 Algorithme de Formation de Swarm**

1. **Collecte des Seeds** : Chaque station génère un `_swarm.egg.txt` unique
2. **Agrégation** : Les seeds de toutes les stations sont collectés
3. **Génération déterministe** : La `swarm.key` est créée à partir des seeds triés
4. **Synchronisation** : Toutes les stations obtiennent la même clé

#### **🔐 Sécurité et Consensus**

```bash
# Génération de la clé swarm partagée
MAGIX=($(printf "%s\n" "${SEEDS[@]}" | sort -u))
echo "/key/swarm/psk/1.0.0/
/base16/
$(echo "${MAGIX[@]}" | tr -d '\n ' | head -c 64)" > swarm.key
```

#### **📍 Filtrage Géographique**

- **Coordonnées GPS** : Latitude et longitude arrondies à l'entier
- **Région commune** : `REGION_${lat}_${lon}` identique pour toutes les stations
- **Distance maximale** : ~100km (1 degré GPS ≈ 111km)

#### **⚡ Prérequis Techniques**

- **Niveau Y** : Station autonome avec concordance SSH ↔ IPFS
- **Connectivité WAN** : Adresse IP publique (ou règles NAT)
- **Ports ouverts** : IPFS (4001), SSH (22), /12345, :54321 (1234 deprecated)
- **GPS activé** : Coordonnées géographiques disponibles

---

## 🏛️ **INFRASTRUCTURE UPLANET**

### **💰 Portefeuilles Créés**

L'initialisation UPLANET crée automatiquement :

| Portefeuille | Rôle | Source primale |
|-------------|------|----------------|
| **UPLANETNAME_G1** | Réserve Ğ1 | Source principale |
| **UPLANETNAME** | Services & MULTIPASS | UPLANETNAME_G1 |
| **UPLANETNAME_SOCIETY** | Capital social | UPLANETNAME_G1 |
| **UPLANETNAME_CASH** | Trésorerie (1/3) | UPLANETNAME_G1 |
| **UPLANETNAME_RND** | R&D (1/3) | UPLANETNAME_G1 |
| **UPLANETNAME_ASSETS** | Actifs (1/3) | UPLANETNAME_G1 |
| **UPLANETNAME_IMPOT** | Fiscalité | UPLANETNAME_G1 |
| **NODE** | Armateur | UPLANETNAME_G1 |

### **🔐 Sécurité Primale**

Tous les portefeuilles sont protégés par le système de contrôle primal :
- **Source unique** : `UPLANETNAME_G1`
- **Anti-intrusion** : Redirection automatique des fonds non autorisés
- **Traçabilité** : Chaîne primale vérifiable

---

## 🎮 **INTERFACES DE GESTION**

### **📊 Tableau de Bord Principal**

```bash
~/.zen/Astroport.ONE/tools/dashboard.sh
```

**Actions rapides :**
- `o` → Virements officiels (UPLANET.official.sh)
- `z` → Analyse économique (zen.sh)
- `u` → Assistant UPlanet ẐEN
- `c` → Changer de capitaine
- `n` → Nouvel embarquement

### **🏛️ Virements Officiels**

```bash
~/.zen/Astroport.ONE/UPLANET.official.sh
```

**Fonctionnalités :**
- Virement MULTIPASS : Recharge MULTIPASS
- Virement SOCIÉTAIRE : Parts sociales + répartition 3x1/3
- Apport CAPITAL INFRASTRUCTURE : Valorisation machine → NODE (direct)
- Vérification automatique blockchain

### **🔍 Analyse Économique**

```bash
~/.zen/Astroport.ONE/tools/zen.sh
```

**Fonctionnalités :**
- Analyse détaillée des portefeuilles
- Reporting OpenCollective
- Diagnostic des chaînes primales
- Transactions manuelles exceptionnelles

---

## 🔄 **MISE À JOUR CONFIGURATION**

### **Pour Utilisateurs Existants**

```bash
# Script de mise à jour
~/.zen/Astroport.ONE/update_config.sh

# Options en ligne de commande
~/.zen/Astroport.ONE/update_config.sh --update    # Mise à jour
~/.zen/Astroport.ONE/update_config.sh --show      # Affichage config
~/.zen/Astroport.ONE/update_config.sh --onboard   # Embarquement
```

### **Fichier de Configuration**

```bash
# Emplacement
~/.zen/Astroport.ONE/.env

# Template
~/.zen/Astroport.ONE/.env.template
```

### **Intégration HeartBox Analysis**

L'assistant utilise `heartbox_analysis.sh` pour :

```bash
# Analyse système en temps réel
~/.zen/Astroport.ONE/tools/heartbox_analysis.sh export --json

# Données obtenues automatiquement :
• Ressources système (CPU, RAM, disque)
• Capacités d'hébergement calculées
• État des services (IPFS, Astroport, uSPOT, NOSTR)
• Espaces de stockage disponibles
• Slots ZEN Cards et MULTIPASS
```

**Avantages :**
- **Données en temps réel** : Plus de variables statiques dans `.env`
- **Calculs précis** : Capacités basées sur l'espace réellement disponible
- **Monitoring intégré** : État des services affiché automatiquement
- **Performance optimisée** : Cache intelligent avec TTL de 5 minutes

---

## 🤝 **ADHÉSION COOPÉRATIVE**

### **💰 Apport au Capital**

Votre machine devient un apport au capital social :
- **Valorisation** : Selon type et ressources
- **Parts sociales** : Proportionnelles à l'apport
- **Droits** : Vote, gouvernance, répartition bénéfices

### **🏛️ Gouvernance**

- **1 membre = 1 voix** (indépendamment de l'apport)
- **Décisions collectives** via assemblées générales
- **Transparence** : Comptabilité ouverte et vérifiable

### **📊 Répartition 3x1/3**

Les bénéfices sont répartis selon la règle coopérative :
- **1/3 Trésorerie** : Fonds de roulement
- **1/3 R&D** : Innovation et développement
- **1/3 Actifs** : Investissements long terme

---

## 🆘 **SUPPORT & RESSOURCES**

### **📚 Documentation**

- **Constitution ẐEN** : `~/.zen/Astroport.ONE/RUNTIME/ZEN.ECONOMY.readme.md`
- **Rôles des scripts** : `~/.zen/Astroport.ONE/SCRIPTS.ROLES.md`
- **Politique anti-intrusion** : `~/.zen/Astroport.ONE/RUNTIME/ZEN.INTRUSION.POLICY.md`

### **🌐 Liens Utiles**

- **Blog** : https://www.copylaradio.com
- **Station** : http://localhost:12345
- **UPassport** : http://localhost:54321
- **Passerelle IPFS** : https://ipfs.copylaradio.com
- **Support** : support@qo-op.com

### **🔧 Dépannage**

```bash
# Vérification système
~/.zen/Astroport.ONE/test.sh

# Réinitialisation UPLANET
~/.zen/Astroport.ONE/UPLANET.init.sh

# Diagnostic économique
~/.zen/Astroport.ONE/tools/zen.sh

# Diagnostic réseau et swarm
ipfs swarm peers                    # Vérifier les pairs connectés
ipfs id                            # Afficher l'ID IPFS
cat ~/.ipfs/swarm.key              # Vérifier la clé swarm

# Réinitialisation réseau
~/.zen/Astroport.ONE/RUNTIME/BLOOM.Me.sh reset    # Reset swarm complet
rm ~/.ipfs/swarm.key               # Supprimer la clé swarm
systemctl --user restart ipfs     # Redémarrer IPFS

# Vérification niveau Y
~/.zen/Astroport.ONE/tools/ssh_to_g1ipfs.py       # Concordance SSH ↔ IPFS
```

### **🌍 Commandes Réseau Utiles**

```bash
# Vérifier la région GPS
cat ~/.zen/tmp/${IPFSNODEID}/GPS.json

# Lister les stations de la région
ls ~/.zen/tmp/swarm/*/y_ssh.pub

# Forcer la formation d'un swarm (si 9+ stations)
~/.zen/Astroport.ONE/RUNTIME/BLOOM.Me.sh

# Vérifier les bootstrap nodes
cat ~/.zen/game/MY_boostrap_nodes.txt

# Vérifier les clés SSH autorisées
cat ~/.zen/game/My_boostrap_ssh.txt
```

---

## 🎉 **FÉLICITATIONS !**

Vous êtes maintenant Capitaine d'une ♥️BOX UPlanet ẐEN !

**Prochaines étapes selon votre mode de connexion :**

### **🤝 Si vous avez rejoint une UPlanet existante :**
1. **Contacter les capitaines** de votre UPlanet pour vous présenter
2. **Configurer vos services** d'hébergement selon les standards locaux
3. **Accueillir vos premiers utilisateurs** recommandés par la communauté
4. **Participer aux assemblées** et décisions collectives

### **🌍 Si vous avez créé un nouveau swarm BLOOM :**
1. **Coordonner avec les autres capitaines** de votre région
2. **Établir les règles** de gouvernance locale
3. **Définir les standards** techniques et économiques
4. **Développer l'écosystème** local ensemble

### **🏠 Si vous êtes en réseau privé :**
1. **Suivre les règles** de votre organisation
2. **Configurer selon les besoins** spécifiques
3. **Maintenir la cohérence** avec le groupe
4. **Contribuer aux objectifs** communs

**Bon vent, Capitaine ! 🏴‍☠️**

---

*Dernière mise à jour : $(date +%Y-%m-%d)*
*Guide d'embarquement UPlanet ẐEN - Coopérative des Autohébergeurs*
