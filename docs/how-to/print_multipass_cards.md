# Imprimer les QR codes MULTIPASS et ZenCards

**Problème :** vous souhaitez donner à un utilisateur ses identifiants MULTIPASS ou ZenCard sous forme physique (QR code imprimable).
**Solution :** utiliser G1BILLET (port 33101) ou les outils bash pour générer les QR codes.

---

## Prérequis

- Station Astroport.ONE opérationnelle
- UPassport API accessible (`http://localhost:54321`)
- Le MULTIPASS de l'utilisateur existe déjà (créé via UPassport)

---

## Option A — Via la route `/qr` de UPassport (recommandée)

### 1. Générer le QR via l'API

```bash
# QR code de la clé G1 (MULTIPASS niveau 1)
curl "http://localhost:54321/qr?email=email@exemple.fr&lat=48.85&lon=2.35" \
  --output multipass_qr.png
```

### 2. Choisir le style (paramètre `style`)

| Valeur | Description |
|--------|-------------|
| `ticket` | Ticket papier simple, QR en bas |
| `ZenCard` | Carte format bancaire recto/verso |
| `ZENCARD+@` | ZenCard avec adresse email embarquée |

```bash
curl "http://localhost:54321/qr?email=email@exemple.fr&style=ZenCard" \
  --output zencard.png
```

### 3. Imprimer

Ouvrez le PNG généré et imprimez (format A6 ou carte bancaire selon le style).

---

## Option B — Via le script bash (ligne de commande)

```bash
# Générer un QR MULTIPASS pour un email
cd ~/.zen/Astroport.ONE
./tools/make_NOSTRCARD.sh "email@exemple.fr" "48.85" "2.35"

# Le QR est enregistré dans
ls ~/.zen/tmp/$(ipfs id -f="<id>")/QR/
```

---

## Option C — QR code simple (clé publique G1 uniquement)

```bash
# Générer la clé G1 depuis l'email
G1PUB=$(./tools/keygen -t duniter "email@exemple.fr" "motdepasse")

# Créer le QR
qrencode -t PNG -o multipass_qr.png "$G1PUB"
```

---

## Résultat attendu

Un fichier PNG ou PDF contenant :
- Le QR code de la clé publique Ğ1 (MULTIPASS niveau 1)
- L'adresse NOSTR associée (npub)
- Le domaine de la station d'accueil

---

## Voir aussi

- [IDENTITY_MULTIPASS.md](../reference/IDENTITY_MULTIPASS.md) — structure du MULTIPASS
- [IDENTITY_ZENCARD.md](../reference/IDENTITY_ZENCARD.md) — droits et ressources ZenCard
