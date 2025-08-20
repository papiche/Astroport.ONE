# WireGuard - Guide de Configuration

## 🎯 **Workflow en 3 Étapes**

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
```

### **3. Serveur : Ajouter Client**
```bash
./wireguard_control.sh
# Option 2 : "Ajouter un client LAN"
# Nom client + clé publique
```

## 📋 **Instructions Rapides**

### **Administrateur :**
```bash
# Initialiser serveur
./wireguard_control.sh → Option 1

# Ajouter client
./wireguard_control.sh → Option 2
# Entrer : nom_client + clé_publique_client

# Vérifier
./wireguard_control.sh → Option 4
```

### **Client :**
```bash
# Générer clés
./wg-client-setup.sh
# Copier clé publique → envoyer à admin

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

## ⚠️ **Points Clés**

- **Clés privées** : Jamais partagées
- **Port** : 51820 ouvert sur serveur
- **Réseau** : 10.99.99.0/24
- **Test** : `ping 10.99.99.1`

## 🛠️ **Dépannage**

```bash
# Vérifier service
sudo systemctl status wg-quick@wg0

# Vérifier connexion
sudo wg show

# Logs
sudo journalctl -u wg-quick@wg0
```
