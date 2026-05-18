# Installer Astroport.ONE sur Linux (métal nu)

**Public :** utilisateur Linux (Debian, Ubuntu, Mint) souhaitant faire tourner sa première station.
**Résultat :** station Astroport.ONE opérationnelle en mode ORIGIN, accessible sur `http://localhost:12345`.

**Durée estimée :** 20–40 minutes selon la connexion.

---

## Prérequis

- Linux 64-bit : Debian 12+, Ubuntu 22.04+, Linux Mint 21+
- Utilisateur non-root avec `sudo`
- Accès Internet (téléchargement ~500 Mo)
- Ports libres : 12345, 54321, 7777, 8080, 4001

---

## Étapes

### 1. Lancer l'installation

```bash
bash <(curl -sL https://install.astroport.com)
```

> L'installeur détecte votre distribution, installe les dépendances (IPFS, Python venv, strfry, gcli), configure les services systemd, et crée votre première identité Capitaine.

### 2. Renseigner les informations demandées

L'installeur vous pose 3 questions :
- **Email Capitaine** — utilisé pour dériver votre paire de clés Ğ1/NOSTR (déterministe, mémorisez-le)
- **Domaine** — `localhost` pour un test local, ou votre domaine public
- **Profil** — laissez vide pour le profil standard

### 3. Attendre la fin de l'initialisation

L'installation configure automatiquement :
- Le nœud IPFS (Kubo)
- Le relay NOSTR strfry sur `ws://localhost:7777`
- L'API UPassport sur `http://localhost:54321`
- La carte de station sur `http://localhost:12345`

### 4. Vérifier le démarrage

```bash
# Services systemd
systemctl status astroport upassport strfry ipfs

# Accès web
curl -s http://localhost:12345 | python3 -m json.tool | head -20
```

---

## Résultat attendu

- `http://localhost:12345` — carte de station JSON (IPFSNODEID, capacités, swarm)
- `http://localhost:54321` — UPassport API (création MULTIPASS)
- `ws://localhost:7777` — relay NOSTR strfry actif (NIP-101)

---

## Étapes suivantes

- [Créer votre premier MULTIPASS](../how-to/print_multipass_cards.md)
- [Rejoindre la constellation ẐEN](../explanation/ROLES.md)
- [Architecture complète](../explanation/architecture_overview.md)
