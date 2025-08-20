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

## 🔧 **Améliorations Nécessaires**

### **1. Script Serveur (`wireguard_control.sh`)**
- ✅ Génération automatique des clés
- ✅ Attribution automatique des IPs
- ✅ Interface utilisateur claire
- ❌ Manque de validation des clés
- ❌ Pas de test de connectivité

### **2. Script Client (`wg-client-setup.sh`)**
- ✅ Génération automatique des clés
- ✅ Configuration interactive
- ❌ Demande l'IP avant qu'elle soit attribuée
- ❌ Pas de validation des paramètres serveur

## 🚀 **Workflow Optimisé Recommandé**

### **Version 1 : Workflow Manuel (Actuel)**
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

## 📝 **Instructions pour les Utilisateurs**

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

## ⚠️ **Points d'Attention**

1. **Sécurité des clés** : Les clés privées ne doivent jamais être partagées
2. **Permissions** : Les scripts nécessitent sudo
3. **Réseau** : Vérifier que le port 51820 est ouvert sur le serveur
4. **Sauvegarde** : Les configurations existantes sont sauvegardées automatiquement
5. **Validation** : Toujours tester la connectivité après configuration

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
