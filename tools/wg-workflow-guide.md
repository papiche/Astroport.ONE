# 🌌 WireGuard & IPFS - Guide de Configuration (Astroport.ONE)

Ce guide détaille la mise en place d'un réseau VPN WireGuard conçu spécifiquement pour **contourner les restrictions de type CGNAT** et permettre à de multiples nœuds IPFS (Satellites) d'être accessibles publiquement via l'adresse IP d'un serveur central (HUB).

## 🌐 **Architecture Constellation Astroport.ONE**

### **🏗️ Topologie (HUB & Satellites)**
- **Un seul VPN HUB** par essaim IPFS de chaque UPlanet.
- **Le HUB (Serveur)** dispose d'une adresse IP publique exposée sur Internet.
- **Les Satellites (Clients)** sont derrière des routeurs/CGNAT. Ils se connectent au HUB (Réseau `10.99.99.0/24`).
- **Tout le trafic internet** des Satellites passe par le tunnel WireGuard (`0.0.0.0/0`).

### **🎯 La Magie IPFS : Le Routage Dynamique des Ports**
Puisqu'il n'y a qu'une seule IP publique (celle du HUB) pour tout l'essaim, le système attribue automatiquement un port public unique à chaque Satellite basé sur son IP VPN locale :
- **HUB (10.99.99.1)** ➔ Port Public **4001**
- **Satellite A (10.99.99.2)** ➔ Port Public **4002** (Redirigé automatiquement vers le port 4001 du Satellite A)
- **Satellite B (10.99.99.3)** ➔ Port Public **4003** (Redirigé automatiquement vers le port 4001 du Satellite B)

---

## 🚀 **Démarrage Rapide (Liaison HUB ↔ Satellite)**

### **Étape 1 : Le HUB (Administrateur)**
```bash
# 1. Installer les dépendances
sudo apt install wireguard qrencode curl

# 2. Initialiser le serveur HUB
./wireguard_control.sh
# -> Choisir Option 1 (Initialiser serveur LAN)

# 3. Transmettre l'IP publique et la clé publique du HUB au Satellite.
```

### **Étape 2 : Le Satellite (Client)**
```bash
# 1. Installer les dépendances
sudo apt install wireguard qrencode curl

# 2. Générer ses clés uniques
./wg-client-setup.sh
# -> Copier la "Clé publique client" affichée et l'envoyer à l'Administrateur du HUB.
```

### **Étape 3 : L'Appairage (Administrateur HUB)**
```bash
# 1. Ajouter le Satellite au réseau
./wireguard_control.sh
# -> Choisir Option 2 (Ajouter un client)
# -> Saisir le nom du Satellite et coller sa clé publique.

# 2. Le script génère une ligne de commande complète commençant par :
# ./wg-client-setup.sh auto ...
# -> Copier cette ligne et la transmettre au Satellite.
```

### **Étape 4 : Connexion & IPFS (Satellite)**
```bash
# 1. Exécuter la commande fournie par l'Administrateur
./wg-client-setup.sh auto [IP_HUB] 51820 [CLÉ_HUB] [IP_VPN_ATTRIBUÉE]

# 2. Le script affichera la commande exacte pour configurer IPFS. Exécutez-la :
ipfs config --json Addresses.Announce '["/ip4/IP_DU_HUB/tcp/400X"]'

# 3. Redémarrer le démon IPFS !
```

---

## 📋 **Administration Quotidienne (Commandes utiles)**

### **Sur le HUB (`wireguard_control.sh`) :**
Le script propose un menu interactif gérant automatiquement les règles pare-feu :
- **Option 3 : Supprimer un client** (Met à jour le pare-feu IPFS à chaud, sans couper les autres).
- **Option 4 : Liste des clients** (Affiche les IP et signale l'IPFS cible).
- **Option 6 : Générer QR Code** (Utile pour connecter un smartphone au réseau).

### **Sur le Satellite (`wg-client-setup.sh`) :**
- **Afficher le QR Code de la configuration active :**
  ```bash
  ./wg-client-setup.sh qr
  ```
- **Vérifier que le tunnel est actif :**
  ```bash
  sudo wg show
  ping 10.99.99.1
  curl ifconfig.me # Doit retourner l'IP publique du HUB !
  ```

---

## 📱 **QR Codes & Mobiles**

### **🎯 Cas d'Usage :**
Bien qu'un smartphone ne fasse généralement pas tourner de nœud IPFS complet, il peut rejoindre l'UPlanet en tant que simple client VPN pour accéder aux ressources locales de l'essaim (ex: un site hébergé sur `10.99.99.2`).

### **📱 Utilisation mobile :**
1. L'administrateur crée un client via l'Option 2 de `wireguard_control.sh`.
2. Il génère le QR Code (Option 6).
3. Installer l'app **WireGuard** (Android/iOS).
4. Scanner le QR code affiché à l'écran.
5. Activer le tunnel dans l'app. Vous êtes dans l'UPlanet !

---

## ⚠️ **Contraintes et Règles d'Or**

- 🚨 **Tout le trafic passe par le HUB :** La route `0.0.0.0/0` implique que la navigation internet du Satellite utilise la bande passante du HUB.
- 🚨 **Un HUB par UPlanet :** Pas de duplication. Un seul VPN centralise les connexions IPFS d'un essaim.
- 🚨 **IPFS Announce :** Si un Satellite oublie d'exécuter la commande `ipfs config --json Addresses.Announce...` générée par le script, son nœud IPFS ne sera pas joignable de l'extérieur (Statut Relayed).

---

## ❓ **FAQ & Dépannage**

### **Q : Mon IPFS reste isolé ou très lent (Statut Relayed) ?**
**R :** Vérifiez que vous avez bien configuré l'annonce de port.
1. Regardez votre IP VPN (`ip addr show wg0`). Si c'est `.3`, votre port public est `4003`.
2. Tapez `ipfs config Addresses.Announce`. S'il est vide, exécutez la commande donnée à la fin de l'installation du client.
3. Vérifiez que le port `4003` n'est pas bloqué par le pare-feu du fournisseur cloud hébergeant le HUB.

### **Q : Comment vérifier si les redirections de port fonctionnent sur le HUB ?**
**R :** Exécutez cette commande sur le HUB pour voir la table de routage dynamique :
```bash
sudo iptables -t nat -L WG_IPFS -n -v
```

### **Q : J'ai supprimé un client, l'IP sera-t-elle réutilisée ?**
**R :** Non, pour éviter les conflits et les erreurs de ports IPFS, le script attribue toujours `Dernière_IP_Connue + 1`.

### **Q : Puis-je avoir le même tunnel sur deux appareils ?**
**R :** Une clé privée = Une adresse IP = Un appareil actif à la fois. Si vous l'activez sur votre PC et votre mobile en même temps avec la même configuration, la connexion va sauter. Créez un profil client différent pour chaque appareil.

## 🎮 **Bonus : Cloud Gaming avec Steam Link**

Le HUB VPN étant très performant, il peut être utilisé pour streamer vos jeux depuis le HUB vers un Satellite via Steam Link ou Moonlight, où que vous soyez dans le monde.

### **Configuration de Steam Link (Sur le Satellite) :**
La découverte automatique (Broadcast) n'étant pas transmise à travers le VPN, le couplage doit se faire manuellement :
1. Connectez votre appareil (Satellite) au VPN WireGuard.
2. Lancez l'application Steam Link.
3. Allez dans **Paramètres** > **Ordinateur** > **Autre ordinateur**.
4. Entrez manuellement l'adresse IP du HUB : `10.99.99.1`.
5. Entrez le code PIN affiché sur l'écran du HUB.

### **Astuces pour une latence optimale :**
- **Désactiver la route par défaut :** Si l'appareil Satellite ne sert qu'à jouer, modifiez sa configuration WireGuard : remplacez `AllowedIPs = 0.0.0.0/0` par `AllowedIPs = 10.99.99.0/24`. Cela évite que vos téléchargements annexes ne saturent la connexion du HUB.
- **Bande passante :** Le HUB doit disposer d'une connexion Fibre optique (minimum 30 Mbps d'Upload recommandé pour du 1080p/60fps fluide).