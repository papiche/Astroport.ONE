# Configurer WireGuard pour la communication inter-stations

**Problème :** deux stations Astroport sont derrière des NAT (box ADSL, cloud privé) et ne peuvent pas s'atteindre directement via IPFS swarm.
**Solution :** tunnel WireGuard point-à-point pour garantir la connectivité P2P.

---

## Prérequis

- Deux stations Astroport.ONE opérationnelles
- `wireguard-tools` installé sur les deux (`sudo apt install wireguard-tools`)
- Au moins une station avec une IP publique ou un port forwardé

---

## Étapes

### 1. Générer les clés WireGuard sur chaque station

```bash
# Sur station A
wg genkey | tee /tmp/wg-private-A.key | wg pubkey > /tmp/wg-public-A.key
cat /tmp/wg-public-A.key

# Sur station B
wg genkey | tee /tmp/wg-private-B.key | wg pubkey > /tmp/wg-public-B.key
cat /tmp/wg-public-B.key
```

### 2. Créer la configuration sur station A

```ini
# /etc/wireguard/astro0.conf (station A)
[Interface]
PrivateKey = <clé privée A>
Address = 10.99.0.1/24
ListenPort = 51820

[Peer]
PublicKey = <clé publique B>
AllowedIPs = 10.99.0.2/32
```

### 3. Créer la configuration sur station B

```ini
# /etc/wireguard/astro0.conf (station B)
[Interface]
PrivateKey = <clé privée B>
Address = 10.99.0.2/24

[Peer]
PublicKey = <clé publique A>
Endpoint = <IP publique A>:51820
AllowedIPs = 10.99.0.1/32
PersistentKeepalive = 25
```

### 4. Démarrer l'interface

```bash
# Sur les deux stations
sudo wg-quick up astro0
sudo systemctl enable wg-quick@astro0
```

### 5. Vérifier la connexion

```bash
# Depuis B, pinger A
ping -c 3 10.99.0.1

# Vérifier le handshake WireGuard
sudo wg show
```

### 6. Connecter IPFS via le tunnel

```bash
# Ajouter le peer IPFS de A depuis B (via adresse WireGuard)
IPFS_NODE_A=$(curl -s http://10.99.0.1:12345 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['IPFSNODEID'])")
ipfs swarm connect /ip4/10.99.0.1/tcp/4001/p2p/$IPFS_NODE_A
```

---

## Résultat attendu

```
$ sudo wg show
interface: astro0
  public key: ...
  listening port: 51820

peer: ...
  endpoint: <IP A>:51820
  latest handshake: X seconds ago
  transfer: X KiB received, X KiB sent
```

Les deux stations voient leur nœud IPFS pair dans `ipfs swarm peers`.

---

## Voir aussi

- [DRAGONS_and_TUNNELS.md](DRAGONS_and_TUNNELS.md) — tunnels IPFS P2P natifs
- [ASTROSYSTEMCTL.md](ASTROSYSTEMCTL.md) — gestion des services à distance
