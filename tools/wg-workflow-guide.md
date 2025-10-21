# WireGuard - Guide de Configuration

## 🚀 **Démarrage Rapide (5 minutes)**

### **Pour l'Administrateur :**
```bash
# 1. Installer les dépendances
sudo apt install wireguard qrencode curl

# 2. Initialiser le serveur
./wireguard_control.sh → Option 1

# 3. Noter la clé publique serveur affichée
```

### **Pour le Client :**
```bash
# 1. Installer WireGuard
sudo apt install wireguard

# 2. Générer les clés
./wg-client-setup.sh

# 3. Envoyer la clé publique à l'admin
```

### **Retour Administrateur :**
```bash
# 4. Ajouter le client
./wireguard_control.sh → Option 2
# Entrer : nom_client + clé_publique_client

# 5. Générer QR code pour mobile (optionnel)
./wireguard_control.sh → Option 6
```

---

## 🎯 **Workflow Détaillé en 3 Étapes**

### **1. Serveur : Initialiser**
```bash
./wireguard_control.sh
# Option 1 : "Initialiser serveur LAN"
# Noter la clé publique serveur
```

### **2. Client : Générer Clés**
```bash
./wg-client-setup.sh
# Noter la clé publique client
# La fournir à l'administrateur
# Optionnel : Générer QR code pour mobile
```

### **3. Serveur : Ajouter Client**
```bash
./wireguard_control.sh
# Option 2 : "Ajouter un client LAN"
# Nom client + clé publique
# Optionnel : Générer QR code pour le client
```

## 📋 **Instructions Rapides**

### **Administrateur :**
```bash
# Initialiser serveur
./wireguard_control.sh → Option 1

# Ajouter client
./wireguard_control.sh → Option 2
# Entrer : nom_client + clé_publique_client

# Générer QR code pour client mobile
./wireguard_control.sh → Option 6

# Vérifier
./wireguard_control.sh → Option 4
```

### **Client :**
```bash
# Générer clés
./wg-client-setup.sh
# Copier clé publique → envoyer à admin
# Optionnel : Générer QR code pour mobile

# Après ajout par admin
sudo cp /etc/wireguard/[nom]_lan.conf /etc/wireguard/wg0.conf
sudo systemctl enable --now wg-quick@wg0
ping 10.99.99.1
```

## 🔧 **Configuration Client**

### **Automatique (Recommandé) :**
```bash
./wg-client-setup.sh auto [IP_SERVEUR] 51820 [CLÉ_SERVEUR] [IP_CLIENT]
```

### **Interactive :**
```bash
./wg-client-setup.sh
# Entrer : IP serveur, port 51820, clé serveur, IP client
```

## 📱 **QR Codes pour Mobile**

### **🎯 Cas d'Usage :**
- **Transfert vers smartphone** - Client existant → Mobile
- **Configuration rapide** - Éviter la saisie manuelle
- **Partage sécurisé** - Donner accès temporaire
- **Backup mobile** - Avoir le tunnel sur plusieurs appareils

### **Générer QR code :**
```bash
# Pour configuration existante
./wg-client-setup.sh qr

# Script dédié
./generate_qr.sh [config_file]

# Depuis le serveur
./wireguard_control.sh → Option 6
```

### **📱 Utilisation mobile :**
1. **Installer** l'app WireGuard (Android/iOS)
2. **Scanner** le QR code affiché
3. **Activer** le tunnel dans l'app
4. **Tester** : `ping 10.99.99.1` (depuis l'app)

## 🎬 **Scénarios Pratiques**

### **📱 Scénario 1 : Client → Mobile**
```bash
# Client déjà configuré
./wg-client-setup.sh qr
# Scanner avec l'app Android/iOS
# Tunnel transféré vers mobile
```

### **🔄 Scénario 2 : Basculement d'Appareil**
```bash
# Désactiver sur ordinateur
sudo systemctl stop wg-quick@wg0

# Activer sur mobile (via l'app)
# Tunnel maintenant sur mobile
```

### **👥 Scénario 3 : Ajout d'un Nouveau Client**
```bash
# Admin : Ajouter client
./wireguard_control.sh → Option 2
# Client : ./wg-client-setup.sh
# Admin : Générer QR code
./wireguard_control.sh → Option 6
```

## ⚠️ **Points Clés**

- **Clés privées** : Jamais partagées
- **Port** : 51820 ouvert sur serveur
- **Réseau** : 10.99.99.0/24
- **Test** : `ping 10.99.99.1`
- **Un seul actif** : Un appareil connecté à la fois

## 🌐 **Architecture Constellation Astroport.ONE**

### **🏗️ Contraintes Architecturales :**
- **Un seul VPN HUB** par essaim IPFS de chaque UPlanet
- **Hub central** : Point d'entrée unique pour tous les satellites
- **Satellites** : Se connectent au HUB de leur UPlanet
- **Isolation** : Chaque UPlanet a son propre réseau VPN (10.99.99.0/24)

### **🎯 Rôle du HUB :**
- **Point d'entrée** pour tous les satellites de l'UPlanet
- **Gestion centralisée** des connexions
- **Routage** vers les services IPFS P2P locaux
- **Sécurité** : Contrôle d'accès unique

### **🔄 Gestion Multi-UPlanet :**
```bash
# UPlanet A (10.99.99.0/24)
./wireguard_control.sh → Option 1
# HUB A configuré

# UPlanet B (10.99.98.0/24) - Réseau différent
./wireguard_control.sh → Option 1
# HUB B configuré

# Chaque UPlanet = Un HUB unique
# Chaque satellite = Un seul HUB à la fois
```

### **⚠️ Contraintes Importantes :**
- **Un HUB par UPlanet** - Pas de duplication
- **Réseaux isolés** - Chaque UPlanet a son sous-réseau
- **Satellites dédiés** - Un satellite = Un UPlanet
- **Pas de croisement** - Les satellites ne peuvent pas changer d'UPlanet

### **✅ Validation Architecture :**
```bash
# Vérifier qu'il n'y a qu'un seul HUB actif
sudo wg show

# Vérifier le réseau assigné
ip addr show wg0

# Vérifier les clients connectés
sudo wg show wg0
```

### **🚨 Erreurs à Éviter :**
- ❌ **Plusieurs HUBs** sur le même UPlanet
- ❌ **Réseaux identiques** entre UPlanets
- ❌ **Satellites croisés** entre UPlanets
- ❌ **Conflits d'IP** dans le même essaim

## 📦 **Dépendances**

### **Serveur :**
```bash
sudo apt install wireguard qrencode curl
```

### **Client :**
```bash
sudo apt install wireguard qrencode
# Optionnel pour QR codes
```

## 🎛️ **Menu Principal (wireguard_control.sh)**

1. 🚀 **Initialiser serveur LAN** - Configuration initiale
2. 👥 **Ajouter un client LAN** - Ajouter un nouveau client
3. 🗑️ **Supprimer un client** - Retirer un client
4. 📋 **Liste des clients** - Voir tous les clients
5. 📖 **Expliquer configuration client** - Instructions détaillées
6. 📱 **Générer QR code client** - QR code pour mobile
7. 🔄 **Redémarrer service** - Redémarrer WireGuard
8. ❌ **Quitter**

## ❓ **FAQ - Questions Fréquentes**

### **Q : Comment transférer mon tunnel vers mon smartphone ?**
```bash
./wg-client-setup.sh qr
# Scanner le QR code avec l'app WireGuard
```

### **Q : Puis-je avoir le tunnel sur plusieurs appareils ?**
**R :** Oui, mais un seul actif à la fois. Basculez avec :
```bash
# Ordinateur → Mobile
sudo systemctl stop wg-quick@wg0
# Puis activer dans l'app mobile
```

### **Q : Comment vérifier que ça fonctionne ?**
```bash
# Vérifier le service
sudo systemctl status wg-quick@wg0

# Tester la connectivité
ping 10.99.99.1

# Voir les connexions
sudo wg show
```

### **Q : Le QR code ne fonctionne pas ?**
```bash
# Vérifier qrencode
sudo apt install qrencode

# Tester la génération
./generate_qr.sh
```

### **Q : Puis-je avoir plusieurs HUBs sur le même UPlanet ?**
**R :** Non ! Un seul VPN HUB par essaim IPFS de chaque UPlanet. C'est une contrainte architecturale.

### **Q : Comment gérer plusieurs UPlanets ?**
**R :** Chaque UPlanet a son propre HUB avec un réseau différent :
```bash
# UPlanet A : 10.99.99.0/24
# UPlanet B : 10.99.98.0/24
# UPlanet C : 10.99.97.0/24
```

### **Q : Un satellite peut-il changer d'UPlanet ?**
**R :** Non, un satellite est dédié à un UPlanet. Pas de croisement possible.

## 🛠️ **Dépannage**

```bash
# Vérifier service
sudo systemctl status wg-quick@wg0

# Vérifier connexion
sudo wg show

# Logs
sudo journalctl -u wg-quick@wg0

# Test QR code
./generate_qr.sh
```
