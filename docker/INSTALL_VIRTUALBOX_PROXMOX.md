# 🖥️ Astroport.ONE — VirtualBox & Proxmox VE

## 📦 Option 1 : VirtualBox + Vagrant (plus simple, pour tester)

### Qu'est-ce que Vagrant ?
Vagrant est un outil qui **automatise la création de VMs VirtualBox**. Pas besoin de configurer VirtualBox manuellement, d'installer un OS, etc. — Une commande suffit.

### Installation (à faire une seule fois)

1. **Installez VirtualBox** :  
   https://www.virtualbox.org/wiki/Downloads  
   *(Version 7.x recommandée — Windows, Mac, Linux)*

2. **Installez Vagrant** :  
   https://developer.hashicorp.com/vagrant/install  
   *(Version 2.4.x)*

### Utilisation

```bash
# Télécharger Astroport.ONE
git clone https://github.com/papiche/Astroport.ONE.git
cd Astroport.ONE/docker/

# Créer la VM et installer Astroport (20-40 min à la première exécution)
vagrant up

# → Télécharge Ubuntu 22.04 automatiquement (~2 Go)
# → Crée la VM dans VirtualBox
# → Installe toutes les dépendances
# → Lance Astroport.ONE
```

**Accès aux services** depuis votre navigateur sur la machine hôte :
```
http://localhost:12345   Astroport (carte de l'essaim)
http://localhost:54321   UPassport (créer votre MULTIPASS)
http://localhost:8080    IPFS Gateway
ws://localhost:7777      Relai NOSTR
```

### Commandes Vagrant utiles

```bash
vagrant up          # Démarrer / créer la VM
vagrant halt        # Arrêter la VM (données conservées)
vagrant ssh         # Accéder au terminal de la VM
vagrant destroy     # Supprimer la VM complètement
vagrant status      # Voir l'état de la VM

# Démarrer avec un profil spécifique :
PROFILE=nextcloud vagrant up        # + NextCloud 128Go
PROFILE=ai-company vagrant up    # + Open WebUI + LiteLLM + Qdrant

# Réseau bridged (VM sur votre réseau local — meilleur pour IPFS P2P) :
VM_NETWORK=bridge vagrant up

# Plus de RAM/CPU :
VM_MEMORY=8192 VM_CPUS=4 vagrant up
```

### Architecture VirtualBox

```
Machine Hôte (Windows/Mac/Linux)
  └─ VirtualBox (hyperviseur)
       └─ VM Ubuntu 22.04 "Astroport.ONE"
            ├─ IPFS daemon
            ├─ strfry relay
            ├─ UPassport
            ├─ Docker
            │    ├─ npm (Nginx Proxy Manager)
            │    ├─ nextcloud-aio (si profil nextcloud)
            │    └─ ai-company-swarm (si profil ai-company)
            └─ Port forwarding → localhost:XXXX
```

> ⚠️ **Pour IPFS P2P** : avec le réseau NAT par défaut, votre nœud peut trouver des pairs mais les connexions entrantes seront bloquées. Utilisez `VM_NETWORK=bridge` pour une connectivité complète.

---

## 🏗️ Option 2 : Proxmox VE (recommandé pour production)

### Qu'est-ce que Proxmox VE ?
Proxmox est un **hyperviseur de type 1** (direct sur le matériel, sans OS hôte). Il est bien plus performant que VirtualBox et conçu pour la production. Interface web sur `https://IP_PROXMOX:8006`.

### Choix du type de VM

| | **VM KVM** | **Conteneur LXC** |
|---|---|---|
| Performance | ✅ Très bonne | ⭐ Excellente (quasi-native) |
| Isolation | ✅ Complète | ⚠️ Partagée |
| Docker support | ✅ Natif | ⚠️ Nécessite config spéciale |
| Recommandé pour | Production standard | Serveurs légers sans Docker |

**Recommandation : VM KVM** pour Astroport.ONE (utilise Docker).

### Méthode A : VM KVM (recommandée)

```bash
# Sur le nœud Proxmox (ou via l'interface web)
bash <(curl -sL https://raw.githubusercontent.com/papiche/Astroport.ONE/master/docker/proxmox-setup.sh)
```

Ou manuellement :

**1. Télécharger l'ISO Ubuntu 22.04** dans Proxmox :
```
Datacenter → VOTRE_NODE → local → ISO Images → Download from URL
URL: https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso
```

**2. Créer la VM** (interface web) :
- RAM : 4096 Mo minimum (8192 recommandé)
- Disque : 80 Go minimum (200 Go recommandé pour IPFS + NextCloud)
- CPU : 2 cœurs minimum, 4 recommandés
- Réseau : Bridge sur votre interface réseau principale (vmbr0)
- Cocher "QEMU Guest Agent"

**3. Installer Ubuntu Server** (sans interface graphique)

**4. Installer Astroport** dans la VM :
```bash
# Dans la VM Ubuntu
bash <(curl -sL https://install.astroport.com)
```

### Méthode B : Script automatisé (CLI Proxmox)

```bash
# Depuis la console Proxmox ou via SSH sur le nœud Proxmox
curl -sL https://raw.githubusercontent.com/papiche/Astroport.ONE/master/docker/proxmox-setup.sh | bash
```

### Méthode C : Conteneur LXC (avancé, Docker nécessite mode privilégié)

```bash
# Télécharger le template Ubuntu 22.04
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst

# Créer le conteneur (ID=200, modifiez selon vos besoins)
pct create 200 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname astroport \
  --memory 4096 \
  --swap 2048 \
  --cores 2 \
  --rootfs local-lvm:80 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 0 \
  --features nesting=1,keyctl=1

# Démarrer le conteneur
pct start 200
pct exec 200 -- bash -c "bash <(curl -sL https://install.astroport.com)"
```

> ⚠️ **Conteneur LXC** : Docker nécessite `--unprivileged 0` (mode privilégié) et `nesting=1`. Cela réduit l'isolation mais fonctionne pour Astroport.

### Accès réseau sur Proxmox

Avantage de Proxmox : la VM a une **vraie IP** sur votre réseau — pas de port forwarding nécessaire.

```
# Dans Proxmox, la VM a par ex. l'IP 192.168.1.50
http://192.168.1.50:12345    Astroport
http://192.168.1.50:54321    UPassport
http://192.168.1.50:80       NPM (HTTP)
https://192.168.1.50:443     NPM (HTTPS)
# etc.
```

Pour exposer sur Internet : configurez vos DNS et Let's Encrypt via NPM.

### Architecture Proxmox recommandée

```
Proxmox VE (bare-metal)
  ├─ VM 100 : Astroport.ONE (Ubuntu 22.04, 4 cores, 8Go RAM, 200Go)
  │    ├─ Docker : npm + astroport + strfry + UPassport
  │    ├─ Docker : nextcloud-aio (profil nextcloud)
  │    └─ Docker : ai-company-swarm (profil ai-company)
  ├─ VM 101 : (autre station Astroport?) → constellation !
  └─ VM 102 : (backup, monitoring, etc.)
```

### Script d'automatisation Proxmox

```bash
# docker/proxmox-setup.sh — voir ce fichier pour l'automatisation complète
```

---

## 💡 Comparaison des méthodes d'installation

| | VirtualBox+Vagrant | Proxmox VM | Proxmox LXC | Direct Linux |
|---|---|---|---|---|
| **Facilité** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Performance** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Isolation** | ✅ | ✅ | ⚠️ | ❌ |
| **IPFS P2P** | Bridge requis | ✅ | ✅ | ✅ |
| **Docker** | ✅ | ✅ | ⚠️ Privilégié | ✅ |
| **Usage recommandé** | Test/Dev | Production | Avancé | Production |

---

## 📞 Support

- Email : support@qo-op.com
- Forum : forum.monnaie-libre.fr
- Code : github.com/papiche/Astroport.ONE
