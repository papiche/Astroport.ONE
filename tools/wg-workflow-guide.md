# WireGuard Workflow Guide - Procédure Simplifiée

## 🎯 **Workflow Corrigé et Simplifié**

### **Étape 1 : Configuration du Serveur**
```bash
# Sur le serveur
cd Astroport.ONE/tools
./wireguard_control.sh
# Choisir option 1 : "Initialiser serveur LAN"
```

**Résultat :**
- Serveur WireGuard configuré sur le port 51820
- Clé publique serveur générée et affichée
- Réseau VPN : 10.99.99.0/24

### **Étape 2 : Préparation du Client**
```bash
# Sur le client
cd Astroport.ONE/tools
./wg-client-setup.sh
# Le script génère les clés et affiche la clé publique client
```

**Résultat :**
- Clés client générées
- Clé publique client affichée
- **IMPORTANT :** Noter cette clé publique

### **Étape 3 : Ajout du Client au Serveur**
```bash
# Sur le serveur
./wireguard_control.sh
# Choisir option 2 : "Ajouter un client LAN"
# Entrer le nom du client et sa clé publique
```

**Résultat :**
- Client ajouté au serveur
- IP automatiquement attribuée (10.99.99.2, 10.99.99.3, etc.)
- Configuration client générée

### **Étape 4 : Finalisation du Client**
```bash
# Sur le client
# Utiliser la configuration générée par le serveur
sudo cp /etc/wireguard/[nom_client]_lan.conf /etc/wireguard/wg0.conf
sudo systemctl enable --now wg-quick@wg0
```

## 🔧 **Améliorations Apportées**

### **1. Script Serveur (`wireguard_control.sh`)**
- ✅ Génération automatique des clés
- ✅ Attribution automatique des IPs
- ✅ Interface utilisateur claire
- ✅ **NOUVEAU :** Instructions de configuration client corrigées
- ✅ **NOUVEAU :** Validation des clés et paramètres
- ✅ **NOUVEAU :** Tests de connectivité inclus

### **2. Script Client (`wg-client-setup.sh`)**
- ✅ Génération automatique des clés
- ✅ Configuration interactive
- ✅ **NOUVEAU :** Validation des paramètres serveur
- ✅ **NOUVEAU :** Mode automatique avec validation
- ✅ **NOUVEAU :** Gestion des erreurs améliorée

## 🚀 **Workflow Optimisé Recommandé**

### **Version 1 : Workflow Manuel (Actuel - Corrigé)**
1. **Serveur** : Initialise le serveur WireGuard
2. **Client** : Génère ses clés et fournit sa clé publique
3. **Serveur** : Ajoute le client avec sa clé publique
4. **Client** : Utilise la configuration générée par le serveur

### **Version 2 : Workflow Automatisé (Recommandé)**
1. **Serveur** : Initialise le serveur WireGuard
2. **Client** : Exécute un script qui :
   - Génère ses clés
   - Envoie sa clé publique au serveur via SSH/API
   - Récupère automatiquement sa configuration
   - Active la connexion

## 📝 **Instructions Détaillées pour les Utilisateurs**

### **Pour l'Administrateur Serveur :**
```bash
# 1. Initialiser le serveur
./wireguard_control.sh
# Choisir option 1

# 2. Noter la clé publique serveur affichée
# 3. La partager avec les clients

# 4. Ajouter chaque client
./wireguard_control.sh
# Choisir option 2
# Entrer nom + clé publique du client

# 5. Vérifier les clients connectés
./wireguard_control.sh
# Choisir option 4

# 6. Expliquer la configuration à un client
./wireguard_control.sh
# Choisir option 5
# Sélectionner le client
# Suivre les instructions affichées
```

### **Pour le Client :**
```bash
# 1. Générer les clés
./wg-client-setup.sh
# Noter la clé publique affichée

# 2. Fournir sa clé publique à l'administrateur

# 3. Attendre que l'administrateur ajoute le client

# 4. Utiliser la configuration générée
sudo cp /etc/wireguard/[nom]_lan.conf /etc/wireguard/wg0.conf
sudo systemctl enable --now wg-quick@wg0

# 5. Tester la connexion
ping 10.99.99.1
```

## 🔍 **Configuration Client - Instructions Corrigées**

### **Méthode 1 : Configuration Automatique (RECOMMANDÉE)**
```bash
# Sur le client, exécuter la commande complète fournie par le serveur
./wg-client-setup.sh auto [SERVEUR_IP] 51820 [CLÉ_SERVEUR] [IP_CLIENT]
```

**Exemple :**
```bash
./wg-client-setup.sh auto 86.206.179.48 51820 3ZHij2SnNQmAlMG4kat72nsVGoE6/FS2BnHxNlf6BQ0= 10.99.99.2/32
```

### **Méthode 2 : Configuration Interactive**
```bash
# 1. Lancer le script
./wg-client-setup.sh

# 2. Entrer les informations quand demandé :
#    - Adresse du serveur : [IP_SERVEUR]
#    - Port du serveur : 51820
#    - Clé publique du serveur : [CLÉ_SERVEUR]
#    - Adresse IP VPN attribuée : [IP_CLIENT]
```

## ⚠️ **Points d'Attention**

1. **Sécurité des clés** : Les clés privées ne doivent jamais être partagées
2. **Permissions** : Les scripts nécessitent sudo
3. **Réseau** : Vérifier que le port 51820 est ouvert sur le serveur
4. **Sauvegarde** : Les configurations existantes sont sauvegardées automatiquement
5. **Validation** : Toujours tester la connectivité après configuration
6. **Pare-feu** : Vérifier que le pare-feu autorise le trafic WireGuard

## 🔍 **Tests de Validation**

### **Sur le Serveur :**
```bash
sudo wg show wg0
sudo systemctl status wg-quick@wg0
```

### **Sur le Client :**
```bash
sudo wg show wg0
ping 10.99.99.1
curl -I http://10.99.99.1
```

## 🛠️ **Dépannage**

### **Problèmes Courants :**

1. **Service ne démarre pas :**
   ```bash
   sudo systemctl status wg-quick@wg0
   sudo journalctl -u wg-quick@wg0
   ```

2. **Connexion échoue :**
   ```bash
   # Vérifier le pare-feu
   sudo ufw status
   # Vérifier les routes
   ip route show
   ```

3. **Clés invalides :**
   ```bash
   # Regénérer les clés
   sudo rm /etc/wireguard/keys/*
   ./wg-client-setup.sh
   ```

## 📋 **Checklist de Configuration**

### **Serveur :**
- [ ] WireGuard installé
- [ ] Serveur initialisé
- [ ] Port 51820 ouvert
- [ ] Pare-feu configuré
- [ ] Clé publique serveur notée

### **Client :**
- [ ] WireGuard installé
- [ ] Clés générées
- [ ] Clé publique fournie au serveur
- [ ] Configuration reçue du serveur
- [ ] Service activé
- [ ] Connectivité testée
