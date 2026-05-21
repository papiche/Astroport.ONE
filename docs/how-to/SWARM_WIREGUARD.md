# Essaim UPlanet et VPN Constellation — `admin/swarm/`

Les stations Astroport.ONE peuvent se connecter en réseau P2P **chiffré** via WireGuard, et s'échanger des services spécialisés (IA, stockage, calcul) moyennant un abonnement en ẐEN.

---

## Modèle économique de l'essaim

Chaque station publie ses capacités dans `12345.json` (champ `capacities`). Les autres stations découvrent ces offres via `~/.zen/tmp/swarm/*/12345.json`.

```
~/.zen/tmp/swarm/<NODEID>/12345.json
  └── capacities.power_score      → 0-10 Light / 11-40 Standard / 41+ Brain
  └── capacities.provider_ready   → true si le node propose des services IA
  └── services.x_ollama.sh        → service Ollama disponible
  └── services.x_comfyui.sh       → service ComfyUI disponible
```

### Coût d'abonnement

| Composant | Signification |
|-----------|---------------|
| `NCARD`   | Part Armateur (NODE) — rémunère l'infrastructure |
| `ZCARD`   | Part Capitaine — rémunère la gestion du service |
| **Total** | `NCARD + ZCARD` ẐEN/semaine (ex: 1 + 4 = **5 ẐEN/semaine**) |

### S'abonner à un service distant

```bash
# Email d'inscription spécial (format fixe)
capitaine+<NODEID_COURT>-1@domaine.tld

# Le paiement est automatique via ZEN.ECONOMY.sh (quotidien)
# Tier Y Level : paiement depuis le portefeuille du node (secret.dunikey)
# Tier standard : paiement depuis le portefeuille du capitaine
```

### Consulter les notifications d'abonnement reçus

```bash
./admin/swarm/SWARM.notifications.sh
# Lit ~/.zen/tmp/$IPFSNODEID/swarm_subscriptions_received.json
```

### Aide générale du swarm

```bash
./admin/swarm/SWARM.help.sh
# Guide interactif : découverte, abonnement, paiements, tunnels
```

---

## VPN Constellation — WireGuard

WireGuard crée un réseau privé `10.99.99.0/24` entre les stations. Avantages :
- Contourne le CGNAT (stations derrière box FAI sans IP publique)
- Permet à IPFS de s'annoncer via l'IP du serveur VPN (port dédié `4000+octet`)
- Chiffrement bout-en-bout (Curve25519 + ChaCha20)

### Architecture réseau

```
Station SERVEUR (IP publique)          Stations CLIENTS (derrière CGNAT)
  wg0 : 10.99.99.1                       wg0 : 10.99.99.2, .3, .4...
  Port WireGuard : 51820                 Port IPFS exposé : 4002, 4003, 4004...
  Firewall IPFS dynamique
```

Le port IPFS de chaque client est calculé automatiquement :
`port_ipfs = 4000 + dernier_octet_IP` (ex: `10.99.99.3` → port `4003`)

---

## Configurer un serveur WireGuard

```bash
sudo ./admin/swarm/wireguard_control.sh
```

Menu interactif (requiert sudo) :

| Option | Action |
|--------|--------|
| `1` | Initialiser le serveur LAN (génère clés, configure `wg0`, démarre systemd) |
| `2` | Ajouter un client (nom + clé publique du client) |
| `3` | Supprimer un client |
| `4` | Synchroniser config + pare-feu IPFS |
| `5` | Redémarrer le service |

Après init, le serveur écoute sur **port 51820/UDP** et crée un script pare-feu IPFS dynamique dans `/etc/wireguard/ipfs-fw.sh`.

---

## Configurer un client WireGuard

```bash
# Mode interactif (demande l'endpoint du serveur)
sudo ./admin/swarm/wg-client-setup.sh

# Mode automatique (scripting)
sudo ./admin/swarm/wg-client-setup.sh auto <endpoint> <port> <ip_client> <pubkey_serveur>
# Exemple :
sudo ./admin/swarm/wg-client-setup.sh auto 203.0.113.10 51820 10.99.99.2/32 <SERVER_PUBKEY>

# Générer un QR code (pour app mobile WireGuard)
sudo ./admin/swarm/wg-client-setup.sh qr
```

Après configuration, activer IPFS sur le VPN :

```bash
# Remplacer SERVER_IP par l'IP publique du serveur VPN
# Remplacer 4002 par votre port (4000 + dernier octet de votre IP VPN)
ipfs config --json Addresses.Announce '["/ip4/SERVER_IP/tcp/4002"]'
sudo systemctl restart ipfs
```

---

## Commandes de contrôle WireGuard

```bash
# État du tunnel
sudo wg show

# Démarrer / arrêter
sudo systemctl start wg-quick@wg0
sudo systemctl stop wg-quick@wg0

# Activer au démarrage
sudo systemctl enable wg-quick@wg0

# Voir la config active
sudo wg showconf wg0
```

---

## Relation avec les tunnels IPFS P2P

WireGuard et les tunnels IPFS P2P (`astrosystemctl enable`) sont complémentaires :

| Mécanisme | Usage | Doc |
|-----------|-------|-----|
| **WireGuard** | VPN permanent, contourne CGNAT, expose IPFS | Ce document |
| **Tunnels IPFS P2P** | Exposition de services HTTP/RPC sur demande | [ASTROSYSTEMCTL.md](ASTROSYSTEMCTL.md) |
| **DRAGON P2P SSH** | Tunnels SSH via IPFS pour accès terminal | [DRAGONS_and_TUNNELS.md](DRAGONS_and_TUNNELS.md) |

---

## Voir aussi

- [ASTROSYSTEMCTL.md](ASTROSYSTEMCTL.md) — CLI P2P cloud (list-remote, connect, enable)
- [DRAGONS_and_TUNNELS.md](DRAGONS_and_TUNNELS.md) — tunnels SSH P2P via IPFS
- [POWER_MONITORING.md](POWER_MONITORING.md) — Power-Score (critère de sélection des Brain Nodes)
- [config_wireguard_vpn.md](config_wireguard_vpn.md) — configuration VPN avancée
