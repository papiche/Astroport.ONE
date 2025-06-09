# Astroport.ONE : Votre Passerelle Personnelle vers l'Écosystème UPlanet

[EN](README.md) - [ES](README.es.md)

**Bienvenue sur Astroport.ONE !** Entrez dans un écosystème numérique révolutionnaire où vous contrôlez vos données, où les paiements s'effectuent de manière transparente à travers des réseaux décentralisés, et où les communautés prospèrent en harmonie avec les rythmes solaires naturels. Astroport.ONE n'est pas juste un logiciel—c'est votre **♥️BOX** (Cœurbox) personnelle, une ambassade numérique complète qui alimente la civilisation décentralisée UPlanet.

## 🌍 **Qu'est-ce qu'UPlanet & Astroport.ONE ?**

**UPlanet** est une civilisation décentralisée synchronisée avec les rythmes naturels de la Terre, où chaque nœud fonctionne en harmonie avec le temps solaire. **Astroport.ONE** est votre passerelle personnelle—une **Station** complète qui sert de :

*   **🏰 Votre Ambassade Numérique** : Un nœud souverain dans le réseau UPlanet avec votre propre domaine et services
*   **🔐 Système d'Identité Résistant Quantique** : Basé sur la cryptographie SSH/GPG avec sécurité Niveau-Y et Niveau-Z
*   **💰 Économie Sans Commission** : Intégration native de la cryptomonnaie Ğ1 (June) avec flux de paiements automatisés
*   **🌐 Maillage de Services P2P** : Partagez et accédez aux ressources IA, stockage et calcul via le Dragon WOT (Web of Trust)
*   **⏰ Synchronisation Temps Solaire** : Toutes les activités de maintenance et réseau synchronisées au temps solaire naturel 20h12

## ✨ **Fonctionnalités Révolutionnaires**

### **🎯 ZenCard & AstroID : Vos Clés Universelles**
- **ZenCard** : Système de paiement basé sur QR-codes intégrant la cryptomonnaie Ğ1
- **AstroID** : Votre identité cryptographique, résistante quantique et complètement sous votre contrôle
- **UPassport** : Système de vérification d'identité inter-plateformes

### **🗃️ Souveraineté des Données Décentralisées**
- **Stockage IPFS Central** : Système de fichiers distribué résistant à la censure
- **Organisation TiddlyWiki** : Base de connaissances personnelle avec tables d'allocation MBR
- **Cache FlashMem** : Clés géographiques (GEOKEYS) pour distribution de données spatiales
- **Intelligence Swarm** : Protocoles de découverte de nœuds et partage de services

### **🤖 Système AstroBot & Vœux**
- **Mots-Clés Vœux** : Définissez des mots-clés personnalisés dans votre TiddlyWiki pour déclencher des smart contracts BASH automatisés
- **Intelligence AstroBot** : Répond aux événements blockchain et aux Vœux pour automatiser votre vie numérique
- **G1PalPay.sh** : Moniteur blockchain Ğ1 en temps réel exécutant des commandes depuis les commentaires de transactions

### **🔗 Dragon WOT : Réseau de Services Décentralisé**
Le **Dragon Web of Trust** permet le tunneling P2P sécurisé de services via IPFS :

- **Accès SSH** : Accès shell sécurisé via tunnels `/x/ssh-{NodeID}`
- **Services IA** : Partage de modèles IA Ollama, ComfyUI, Perplexica
- **Synthèse Vocale** : Partage du service TTS Orpheus
- **Nœuds Niveau-Y** : Vérification de clés SSH par preuve cryptographique
- **Sécurité Niveau-Z** : Authentification basée GPG pour confiance renforcée

### **⏰ Synchronisation Temps Solaire**
Chaque nœud UPlanet fonctionne sur **temps solaire** pour l'harmonie naturelle :
- **Calibration GPS Automatique** : Votre position géographique détermine votre 20h12 solaire
- **cron_VRFY.sh** : Calcule le temps solaire local via coordonnées GPS
- **solar_time.sh** : Correction équation du temps pour alignement solaire précis
- **Synchronisation Globale** : Tous les nœuds exécutent la maintenance au même moment solaire mondial

### **♥️BOX Analyse Système**
Votre station Astroport.ONE surveille continuellement :
- **Ressources Matérielles** : Utilisation CPU, GPU, RAM
- **Capacité Stockage** : Calcul automatique des slots ZenCard (128Go) et NOSTR Card (10Go)
- **Santé IPFS** : Proximité garbage collection, connectivité peers
- **Intégration NextCloud** : Stockage cloud personnel avec monitoring des ports (8001/8002)
- **Systèmes Cache** : Découverte Swarm, profils Coucou, geokeys FlashMem

## 🚀 **Installation & Configuration**

**Installation Automatisée (Linux - Debian/Ubuntu/Mint) :**

```bash
bash <(curl -sL https://install.astroport.com)
```

### **Configuration Capitaine Initiale**
Votre premier compte devient le **Capitaine** de votre ♥️BOX :
- **Collecte GPS** : Votre localisation est automatiquement collectée pour calibration temps solaire
- **Vérification Niveau-Y** : Clés SSH vérifiées via transformation cryptographique
- **Profil NOSTR** : Création automatique du profil capitaine sur réseaux sociaux décentralisés
- **Dragon WOT** : Intégration dans le Web of Trust pour partage de services P2P

### **Processus en Fonctionnement**
Après installation, les services essentiels incluent :
```bash
/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesys-pubsub
/bin/bash ~/.zen/G1BILLET/G1BILLETS.sh daemon
/bin/bash ~/.zen/Astroport.ONE/12345.sh
/bin/bash ~/.zen/Astroport.ONE/_12345.sh
```

## 🔧 **API & Intégration**

### **APIs Centrales**
- **Port 1234** : API Station v1 (réponses : 45780, 45781, 45782)
- **Port 12345** : Carte réseau stations et découverte nœuds
- **Port 33101** : Création G1BILLET (:33102 pour récupération)
- **Port 54321** : API UPassport v2 pour gestion identité
- **Ports IPFS** : 8080 (passerelle), 4001 (swarm), 5001 (API)

### **API Géospatiale UPlanet**
Dédiée aux applications OSM2IPFS et clients UPlanet :

```http
GET /?uplanet=capitaine@domaine.com&zlat=48.85&zlon=2.35&g1pub=fr
```

| Paramètre | Type      | Description                                    |
|-----------|-----------|------------------------------------------------|
| `uplanet` | `email`   | **Requis**. Email du joueur                   |
| `zlat`    | `decimal` | **Requis**. Latitude (précision 2 décimales)  |
| `zlon`    | `decimal` | **Requis**. Longitude (précision 2 décimales) |
| `g1pub`   | `string`  | **Optionnel**. Code langue/origine            |

### **API Réseau Swarm**
- **Découverte Nœuds** : Détection automatique des services dans votre swarm
- **Intégration Paiements** : PAF (Participation Aux Frais) pour abonnements inter-nœuds
- **Tunneling Services** : Accès aux ressources IA, stockage et calcul distantes

## 🎯 **À Qui s'Adresse Astroport.ONE ?**

*   **🏛️ Souverains Numériques** : Individus cherchant contrôle complet sur leur existence numérique
*   **🤝 Communautés Décentralisées** : Groupes construisant des sociétés numériques coopératives
*   **🧠 Développeurs IA** : Accès au partage distribué de modèles IA et ressources de calcul
*   **💱 Écosystème Ğ1** : Intégration native avec la monnaie libre June/Ğ1
*   **🌱 Passionnés Rythmes Solaires** : Ceux cherchant harmonie avec cycles temporels naturels
*   **🔬 Pionniers Web3** : Développeurs construisant la prochaine génération d'applications décentralisées

## 🏗️ **Fonctionnalités Avancées**

### **Économie Inter-Nœuds**
- **Abonnements ZenCard** : Slots de stockage 128Go pour utilisateurs premium
- **NOSTR Cards** : Intégration légère réseaux sociaux 10Go
- **Réserves Capitaine** : Réservation automatique 8 slots pour opérateurs nœuds
- **Paiements Automatisés** : Traitement PAF quotidien pour partage ressources transparent

### **Intégration Services IA**
- **Ollama** : Déploiement et partage LLM locaux
- **ComfyUI** : Workflows avancés génération d'images
- **Perplexica** : Recherche web améliorée avec assistance IA
- **Orpheus TTS** : Partage service synthèse vocale

### **Distribution Géographique**
- **GEOKEYS** : Clés de données spatiales pour distribution contenu géographique
- **Intégration UMAP** : Intégration données OpenStreetMap
- **Gestion Secteurs** : Organisation et cache de données régionales
- **Cartographie TiddlyWiki** : Bases connaissances personnelles avec contexte géographique

## 📚 **Documentation & Communauté**

**Documentation Complète** : https://astroport-1.gitbook.io/astroport.one/

**Contribution** : Ce projet combine les logiciels libres et open-source les plus précieux. Contributions bienvenues sur [opencollective.com/monnaie-libre](https://opencollective.com/monnaie-libre#category-BUDGET).

## 🌟 **Observateurs dans le temps**

[![Observateurs dans le temps](https://starchart.cc/papiche/Astroport.ONE.svg)](https://starchart.cc/papiche/Astroport.ONE)

## 🙏 **Crédits**

Merci à tous ceux qui ont contribué à rendre ce logiciel accessible à tous.

**Découvrez [Ğ1](https://monnaie-libre.fr)** - La meilleure cryptomonnaie dont vous puissiez rêver : libre, décentralisée, et conçue pour le revenu de base universel à travers l'harmonie économique naturelle.
