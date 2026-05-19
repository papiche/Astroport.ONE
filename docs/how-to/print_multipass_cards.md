# Imprimer les QR codes MULTIPASS et ZenCards

**Problème :** vous souhaitez donner à un utilisateur ses identifiants MULTIPASS ou ZenCard sous forme physique (QR code imprimable).
**Solution :** utiliser G1BILLET (port 33101) pour les cartes formatées, ou le générateur QR générique d'UPassport (port 54321) pour encoder n'importe quelle donnée.

---

## Prérequis

- Station Astroport.ONE opérationnelle
- Le MULTIPASS de l'utilisateur existe déjà (créé via UPassport `/g1nostr`)
- La clé publique G1 de l'utilisateur est connue

---

## Option A — Via G1BILLET (port 33101) — cartes formatées

G1BILLET génère des billets et cartes physiques prêtes à imprimer avec QR code intégré.

### 1. Génération via l'interface web

```
http://localhost:33101/?montant=10&style=ZenCard
```

### 2. Styles disponibles (paramètre `style`)

| Valeur | Description |
|--------|-------------|
| `_` | 6 billets G1 anonymes (sans montant fixe) |
| `ticket` (ou nom de dossier images) | Ticket papier simple |
| `ZenCard` | Carte format bancaire recto/verso |
| `email@example.com` | ZenCard liée à l'email (mode `ZENCARD+@`) |

```bash
# Carte ZenCard générique
curl "http://localhost:33101/?montant=10&style=ZenCard"

# ZENCARD+@ liée à un email (intègre l'identité MULTIPASS)
curl "http://localhost:33101/?montant=0&style=user@example.com"
```

### 3. Imprimer

Ouvrez le PNG ou PDF généré et imprimez (format A6 ou carte bancaire selon le style).

---

## Option B — Via la route `/qr` d'UPassport (QR code générique)

La route `/qr` (port 54321) génère un QR code **à partir de n'importe quelle donnée**.
Elle utilise `amzqr` (avec image de fond artistique) ou `qrencode` en fallback.

### Paramètres

| Paramètre | Type | Défaut | Notes |
|-----------|------|--------|-------|
| `data` | string | **requis** | Contenu à encoder (URL, clé G1, texte…) |
| `html` | int | — | `?html=1` → affiche l'interface web de configuration |
| `version` | int 1–40 | `1` | Version QR (auto-incrémentée si overflow) |
| `level` | string | `H` | Correction d'erreur : `L` 7% / `M` 15% / `Q` 25% / `H` 30% |
| `colorized` | int 0\|1 | `0` | Coloriser le QR depuis l'image de fond (`amzqr` requis) |
| `contrast` | float | `1.0` | Contraste de l'image de fond (0.1–3.0) |
| `brightness` | float | `1.0` | Luminosité de l'image de fond (0.1–3.0) |
| `picture_url` | string | — | URL d'une image à télécharger comme fond |
| `color` | string | `000000` | Couleur des modules QR en RRGGBB (fallback qrencode) |
| `bgcolor` | string | `ffffff` | Couleur de fond en RRGGBB (fallback qrencode) |
| `format` | string | `png` | `png` → image directe · `json` → dataUrl base64 |

### 1. QR code de la clé publique G1 (MULTIPASS)

```bash
# Récupérer la clé G1 de l'utilisateur
G1PUB=$(cd ~/.zen/Astroport.ONE && ./tools/keygen -t duniter "email@exemple.fr" "motdepasse")

# Générer le QR
curl "http://localhost:54321/qr?data=${G1PUB}" --output multipass_qr.png
```

### 2. QR artistique avec image de fond

```bash
# Avec image de fond (amzqr doit être installé)
curl "http://localhost:54321/qr?data=${G1PUB}&picture_url=https://example.com/logo.png&colorized=1" \
  --output multipass_qr_art.png
```

### 3. Interface web de configuration

```
http://localhost:54321/qr?html=1
```

Permet de configurer visuellement tous les paramètres et prévisualiser le résultat.

---

## Option C — QR code simple (ligne de commande)

```bash
# Générer la clé G1 depuis l'email
G1PUB=$(cd ~/.zen/Astroport.ONE && ./tools/keygen -t duniter "email@exemple.fr" "motdepasse")

# Créer le QR avec qrencode
qrencode -t PNG -o multipass_qr.png "$G1PUB"
```

---

## Résultat attendu

Un fichier PNG contenant le QR code de la clé publique Ğ1 (MULTIPASS niveau 1).
Pour les cartes complètes (recto/verso avec adresse NOSTR, domaine station, etc.), utiliser G1BILLET (Option A).

---

## Voir aussi

- [IDENTITY_MULTIPASS.md](../reference/IDENTITY_MULTIPASS.md) — structure du MULTIPASS
- [IDENTITY_ZENCARD.md](../reference/IDENTITY_ZENCARD.md) — droits et ressources ZenCard
- [upassport_api_endpoints.md](../reference/upassport_api_endpoints.md) — paramètres complets de `/qr`
