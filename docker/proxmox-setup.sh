#!/bin/bash
########################################################################
# proxmox-setup.sh — Crée une VM Astroport.ONE sur Proxmox VE
#
# Usage : bash proxmox-setup.sh
#   Sur le nœud Proxmox (en root ou via SSH)
#
# Variables d'environnement optionnelles :
#   VM_ID          Identifiant Proxmox (défaut: 200)
#   VM_NAME        Nom de la VM (défaut: astroport)
#   VM_MEMORY      RAM en Mo (défaut: 4096)
#   VM_CORES       Nombre de cœurs (défaut: 2)
#   VM_DISK_SIZE   Disque en Go (défaut: 80)
#   VM_BRIDGE      Interface réseau bridge (défaut: vmbr0)
#   VM_STORAGE     Stockage Proxmox (défaut: local-lvm)
#   ISO_STORAGE    Stockage ISO (défaut: local)
########################################################################

set -e

VM_ID="${VM_ID:-200}"
VM_NAME="${VM_NAME:-astroport}"
VM_MEMORY="${VM_MEMORY:-4096}"
VM_CORES="${VM_CORES:-2}"
VM_DISK_SIZE="${VM_DISK_SIZE:-80}"
VM_BRIDGE="${VM_BRIDGE:-vmbr0}"
VM_STORAGE="${VM_STORAGE:-local-lvm}"
ISO_STORAGE="${ISO_STORAGE:-local}"

## Couleurs
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; C='\033[0;36m'; N='\033[0m'

## Vérification : doit être sur un nœud Proxmox
if ! command -v pveam &>/dev/null && ! command -v qm &>/dev/null; then
    echo -e "${R}❌ Ce script doit être exécuté sur un nœud Proxmox VE.${N}"
    echo ""
    echo "Si vous n'avez pas Proxmox, utilisez Vagrant à la place :"
    echo "  cd docker/ && vagrant up"
    exit 1
fi

echo -e "${C}╔══════════════════════════════════════════════════════════╗${N}"
echo -e "${C}║  🏗️  Astroport.ONE — Création VM Proxmox VE              ║${N}"
echo -e "${C}╠══════════════════════════════════════════════════════════╣${N}"
echo -e "${C}║${N}  VM ID     : ${G}${VM_ID}${N}"
echo -e "${C}║${N}  Nom       : ${G}${VM_NAME}${N}"
echo -e "${C}║${N}  RAM       : ${G}${VM_MEMORY} Mo${N}"
echo -e "${C}║${N}  Cœurs     : ${G}${VM_CORES}${N}"
echo -e "${C}║${N}  Disque    : ${G}${VM_DISK_SIZE} Go${N}"
echo -e "${C}║${N}  Bridge    : ${G}${VM_BRIDGE}${N}"
echo -e "${C}║${N}  Stockage  : ${G}${VM_STORAGE}${N}"
echo -e "${C}╚══════════════════════════════════════════════════════════╝${N}"
echo ""

## Vérifier si la VM existe déjà
if qm status "${VM_ID}" &>/dev/null; then
    echo -e "${Y}⚠️  VM ${VM_ID} existe déjà.${N}"
    read -p "Continuer et écraser ? (y/N) : " confirm
    [[ ! "$confirm" =~ ^[yY] ]] && exit 0
    qm destroy "${VM_ID}" 2>/dev/null || true
fi

## ── Télécharger l'ISO Ubuntu 22.04 ──────────────────────────────────
ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso"
ISO_FILE="${ISO_STORAGE}:iso/ubuntu-22.04.3-live-server-amd64.iso"

echo -e "${G}📥 Vérification ISO Ubuntu 22.04...${N}"
if ! pvesm list "${ISO_STORAGE}" | grep -q "ubuntu-22.04.3-live-server"; then
    echo "Téléchargement de l'ISO Ubuntu 22.04 (~1.4 Go)..."
    pveam download "${ISO_STORAGE}" ubuntu-22.04.3-live-server-amd64.iso 2>/dev/null \
        || wget -q --show-progress -O "/var/lib/vz/template/iso/ubuntu-22.04.3-live-server-amd64.iso" "$ISO_URL"
    echo -e "${G}✅ ISO téléchargée${N}"
else
    echo -e "${G}✅ ISO disponible${N}"
fi

## ── Créer la VM ──────────────────────────────────────────────────────
echo -e "${G}🖥️  Création de la VM ${VM_ID}...${N}"
qm create "${VM_ID}" \
    --name "${VM_NAME}" \
    --memory "${VM_MEMORY}" \
    --cores "${VM_CORES}" \
    --sockets 1 \
    --numa 0 \
    --ostype l26 \
    --machine q35 \
    --cpu host \
    --boot order=ide2 \
    --bios ovmf \
    --efidisk0 "${VM_STORAGE}:0,efitype=4m" \
    --ide2 "${ISO_FILE},media=cdrom" \
    --net0 "virtio,bridge=${VM_BRIDGE}" \
    --agent 1 \
    --onboot 1 \
    --hotplug disk,network,usb \
    --balloon 0

## Ajouter le disque principal
echo -e "${G}💾 Création du disque ${VM_DISK_SIZE}Go...${N}"
qm set "${VM_ID}" --scsi0 "${VM_STORAGE}:${VM_DISK_SIZE},ssd=1,discard=on"

## Activer la virtualisation imbriquée (pour Docker)
qm set "${VM_ID}" --args "-cpu host,+vmx"

echo -e "${G}✅ VM ${VM_ID} (${VM_NAME}) créée${N}"
echo ""
echo -e "${Y}═══════════════════════════════════════════════════════════${N}"
echo -e "${Y}  PROCHAINES ÉTAPES :${N}"
echo -e "${Y}═══════════════════════════════════════════════════════════${N}"
echo ""
echo -e "  ${C}1. Démarrer la VM${N} : qm start ${VM_ID}"
echo -e "     Ou via l'interface web Proxmox"
echo ""
echo -e "  ${C}2. Installer Ubuntu Server${N}"
echo -e "     Connectez-vous via la console noVNC (Proxmox web)"
echo -e "     Choisissez 'Ubuntu Server (minimized)'"
echo -e "     Créez un utilisateur avec sudo"
echo ""
echo -e "  ${C}3. Installer Astroport.ONE${N} dans la VM :"
echo -e "     ${G}bash <(curl -sL https://install.astroport.com)${N}"
echo ""
echo -e "  ${C}Alternative — Cloud-init${N} (si vous avez une image cloud) :"
echo -e "     Remplacez l'ISO par une image Ubuntu cloud-init"
echo -e "     et Astroport se lancera automatiquement"
echo ""
echo -e "${C}Accès Proxmox : https://$(hostname -I | awk '{print $1}'):8006${N}"
echo ""

## ── Option : Créer un Cloud-Init snippet pour auto-install ─────────
cat > /tmp/astroport-cloudinit.yml << 'YAML'
#cloud-config
# Cloud-init snippet pour auto-installer Astroport.ONE
# À copier dans /var/lib/vz/snippets/ sur le nœud Proxmox
# puis attacher avec : qm set VM_ID --cicustom "user=local:snippets/astroport-cloudinit.yml"

package_update: true
package_upgrade: true

packages:
  - curl
  - git

runcmd:
  - sudo -u ubuntu bash -c 'bash <(curl -sL https://install.astroport.com) "" "" "" ""'

final_message: "Astroport.ONE installation complete after $UPTIME seconds"
YAML

echo -e "${C}📋 Snippet Cloud-Init créé : /tmp/astroport-cloudinit.yml${N}"
echo "   Pour l'utiliser avec une image cloud Ubuntu :"
echo "   cp /tmp/astroport-cloudinit.yml /var/lib/vz/snippets/"
echo "   qm set ${VM_ID} --cicustom 'user=local:snippets/astroport-cloudinit.yml'"
