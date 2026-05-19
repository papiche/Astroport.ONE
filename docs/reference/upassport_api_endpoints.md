# UPassport API — Endpoints (port 54321)

**Source de vérité** pour l'API FastAPI UPassport.
Base URL : `http://localhost:54321` · Swagger : `http://localhost:54321/docs`

Tous les routers sont montés à la racine (pas de préfixe path). Les routes sont groupées par domaine fonctionnel.

**Auth :**
- **NIP-42** — token éphémère obtenu via `GET /api/nip42/challenge` + signature kind-22242
- **NIP-98** — event kind-27235 signé, transmis dans `Authorization: Nostr <base64url(event)>`

---

## Statut & Santé

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET` | `/` | Aucune | État station UPlanet (lat, lon, deg → niveau grille UMAP) |
| `GET` | `/health` | Aucune | Health check |
| `GET` | `/rate-limit-status` | Aucune | État du rate limiting pour l'IP appelante |

---

## Identité (MULTIPASS, SSSS)

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `POST` | `/g1nostr` | Aucune | Créer ou récupérer un MULTIPASS (email + géoloc → clés NOSTR + G1) |
| `POST` | `/upassport` | Aucune | Vérifier un UPassport (parametre=pubkey ou QR) |
| `POST` | `/ssss` | Aucune | Reconstructer clé DISCO via Shamir Secret Sharing (T=2, 3 parts) |
| `GET` | `/.well-known/nostr/nip96.json` | NIP-98 optionnel | Descripteur NIP-96 (quotas : MULTIPASS 650 Mo, FREE 100 Mo) |

**Paramètres `POST /g1nostr` :**

| Champ | Type | Notes |
|-------|------|-------|
| `email` | string | Détermine la clé — immuable |
| `lang` | string | Code langue (ex: `fr`) |
| `lat` | float | Latitude UMAP (0.01°) |
| `lon` | float | Longitude UMAP (0.01°) |
| `salt` | string | Auto-généré si vide (24 chars) |
| `pepper` | string | Auto-généré si vide (24 chars) |
| `format` | string | `html` (défaut) ou `json` |

**Paramètres `POST /ssss` :**

| Champ | Type | Notes |
|-------|------|-------|
| `cardns` | string | IPNS path de la ZenCard source |
| `ssss` | string | Part SSSS locale (format `[1-3]-<hex>`) |
| `zerocard` | string | Optionnel |

---

## Finance & Économie

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET` | `/check_balance` | Aucune | Solde G1/ẐEN d'une clé publique ou email |
| `GET` | `/check_balances` | Aucune | Batch soldes (param `g1pubs=pub1,pub2,…`, max 20) |
| `GET` | `/check_zencard` | Aucune | Historique parts ZenCard (`email` requis) |
| `GET` | `/check_society` | Aucune | Historique contributions sociales (SOCIÉTÉ wallet) |
| `GET` | `/check_revenue` | Aucune | Chiffre d'affaires ZENCOIN (param `year=YYYY` optionnel) |
| `GET` | `/check_impots` | Aucune | Provisions fiscales TVA + IS (wallet UPLANET.IMPOT) |
| `POST` | `/oc_webhook` | Signature OC | Webhook OpenCollective → émission ẐEN (transactions coopératives) |
| `POST` | `/zen_send` | NIP-42 | ~~Envoyer ẐEN~~ **DÉPRÉCIÉ** — utiliser Kind 7 (relay 7.sh) |
| `POST` | `/coinflip/start` | Token | Démarrer partie CoinFlip (token issu de `/zen_send`) |
| `POST` | `/coinflip/flip` | Token | Lancer un flip (Heads → pot×2, Tails → fin) |
| `POST` | `/coinflip/payout` | Token | Encaisser les gains (`2^(consecutive-1)` ẐEN) |

---

## Média — Upload

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `POST` | `/api/fileupload` | NIP-42 requis | Upload fichier → IPFS + génération uDRIVE |
| `POST` | `/api/upload` | NIP-42 requis | Alias de `/api/fileupload` |
| `PUT` | `/upload` | NIP-98 requis | **Blossom NIP-24242** — upload compatible Coracle/clients NOSTR |
| `POST` | `/api/upload/image` | Aucune | Upload image générique → IPFS (Coracle-compatible) |
| `POST` | `/upload2ipfs` | NIP-98 optionnel | Upload direct IPFS legacy (réponse NIP-96) |
| `POST` | `/api/upload_from_drive` | NIP-42 requis | Import depuis un autre uDRIVE (`ipfs_link`) |
| `GET` | `/uploads/{filename}` | Aucune | Servir fichier local (protection path traversal) |
| `POST` | `/api/cloud/upload` | NIP-98 | ⚠️ **Placeholder** — non implémenté |

**Blossom `PUT /upload` :**
- Header : `Authorization: Nostr <base64url(kind-24242 event)>`
- Body : bytes du fichier brut
- L'event doit contenir `["x", "<sha256-du-fichier>"]`
- Réponse : `{url, sha256, size, type, ipfs_cid, ipfs_url}`

---

## Média — Webcam & Vocaux

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET` | `/webcam` | Aucune | Page HTML webcam |
| `POST` | `/webcam` | NIP-42 optionnel | Traiter vidéo → IPFS + publier NIP-71 (kind 21) |
| `POST` | `/vocals` | NIP-42 optionnel | Traiter vocal → IPFS + publier kind 1222/1244 (NIP-A0) |

---

## Médiathèque

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET` | `/theater` | Aucune | Interface vidéothèque |
| `GET` | `/mp3-modal` | Aucune | Lecteur MP3 modal |
| `GET` | `/playlist` | Aucune | Playlist uDRIVE |
| `GET` | `/tags` | Aucune | Navigation par tags |
| `GET` | `/contrib` | Aucune | Contributions |
| `GET` | `/youtube` | Aucune | Archives YouTube uDRIVE |
| `GET` | `/mp3` | Aucune | Bibliothèque audio |

---

## NOSTR & Social

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET` | `/nostr` | Aucune | Page NOSTR HTML (param `type=default\|uplanet`) |
| `GET` | `/api/getN2` | Aucune | Graphe N² amis d'amis depuis relay (`hex` requis, opt `range`, `output`) |
| `POST` | `/sendmsg` | Aucune | Envoyer invitation UPlanet par email |
| `POST` | `/api/test-nostr` | Aucune | Tester NIP-42 + vérifier inscription MULTIPASS |
| `GET` | `/api/test-nostr` | Aucune | Alias GET (browser testing) |

---

## Géolocalisation & Auth

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET` | `/api/nip42/challenge` | Aucune | Émettre nonce NIP-42 (TTL 120s, 32 bytes random) |
| `GET` | `/api/myGPS` | NIP-42 requis | Retourner GPS utilisateur (fichier `GPS` ou home station via IPFS) |
| `GET` | `/chat` | Aucune | Page chat UMAP (param `room=lat,lon`) |
| `GET` | `/api/umap/geolinks` | Aucune | Liens géo adjacents (9 directions UMAPs/SECTORs/REGIONs) |

---

## Avatars

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET` | `/robohash/{pubkey}` | Aucune | Générer avatar Robohash **localement** (zéro fuite IP vers robohash.org) |

---

## QR Codes

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET` | `/qr` | Aucune | Générateur QR générique (`data=` requis) · `html=1` → interface web |
| `POST` | `/qr` | Aucune | Générateur QR générique (body multipart — supporte upload d'image de fond) |

**Paramètres `/qr` :**

| Paramètre | Type | Défaut | Notes |
|-----------|------|--------|-------|
| `html` | int | — | `?html=1` → renvoie l'interface de configuration HTML |
| `data` | string | **requis** | Contenu à encoder dans le QR (URL, clé G1, texte…) |
| `version` | int 1–40 | `1` | Version QR (auto-incrémentée si overflow de données) |
| `level` | string | `H` | Niveau de correction d'erreur : `L` / `M` / `Q` / `H` |
| `colorized` | int 0\|1 | `0` | Coloriser le QR depuis l'image de fond (`amzqr` requis) |
| `contrast` | float | `1.0` | Contraste de l'image de fond (0.1–3.0) |
| `brightness` | float | `1.0` | Luminosité de l'image de fond (0.1–3.0) |
| `picture_url` | string | — | URL d'une image à télécharger comme fond artistique |
| `color` | string | `000000` | Couleur modules QR en RRGGBB (fallback qrencode uniquement) |
| `bgcolor` | string | `ffffff` | Couleur fond en RRGGBB (fallback qrencode uniquement) |
| `format` | string | `png` | `png` → image directe · `json` → `{dataUrl, data, engine}` |

> **Note :** pour les billets et cartes formatées (ticket, ZenCard, ZENCARD+@), utiliser **G1BILLET** (port 33101) : `http://localhost:33101/?montant=10&style=ZenCard`.

---

## Analytics

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `POST` | `/ping` | Aucune | Webhook analytics → event NOSTR kind 10600 chiffré (NIP-44) vers captain |

---

## Feedback

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `POST` | `/api/feedback` | Aucune | Rapport de bug → issue GitHub/GitLab automatique (config via kind 30800) |

---

## Oracle / WoTx2 (Verifiable Credentials)

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `POST` | `/api/permit/define` | — | Définir un permis WoTx2 (kind 30500) |
| `GET` | `/api/permit/definitions` | — | Lister toutes les définitions de permis |
| `GET` | `/api/permit/composites` | — | Lister les skills composites |
| `GET` | `/api/permit/stats` | — | Statistiques globales des permis |
| `POST` | `/api/permit/issue/{request_id}` | — | Émettre un credential (kind 30502/30503) |
| `POST` | `/api/permit/revoke/{credential_id}` | — | Révoquer un credential |
| `GET` | `/api/permit/credential/{credential_id}` | — | Détail d'un credential |
| `GET` | `/api/permit/user/credentials` | — | Credentials d'un utilisateur |
| `GET` | `/api/permit/masters` | — | Liste des Masters WoT (émetteurs certifiés) |
| `GET` | `/api/permit/nostr/fetch` | — | Récupérer permis depuis relay NOSTR |
| `POST` | `/api/permit/renewal/request` | — | Demande de renouvellement de permis |
| `GET` | `/oracle` | Aucune | Interface Oracle System |
| `GET` | `/wotx2` | Aucune | Interface WoTx2 |
| `GET` | `/wotx2_renewal` | Aucune | Interface renouvellement WoTx2 |

---

## Crowdfunding

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `POST` | `/api/crowdfunding/create` | Aucune | Créer projet (ID `CF-YYYYMMDD-XXXXXXXX`) |
| `GET` | `/api/crowdfunding/list` | Aucune | Lister projets (param `status=all\|active\|completed`) |
| `GET` | `/api/crowdfunding/status/{project_id}` | Aucune | Détail + solde wallet BIEN |
| `POST` | `/api/crowdfunding/add-owner` | Aucune | Ajouter propriétaire (mode `commons\|cash`) |
| `GET` | `/api/crowdfunding/bien-balance/{project_id}` | Aucune | Solde G1 du wallet BIEN |

---

## IPFS Proxy

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET/HEAD` | `/ipfs/{path}` | Aucune | Proxy vers gateway IPFS locale (port 8080) |
| `GET/HEAD` | `/ipns/{path}` | Aucune | Proxy vers gateway IPNS locale |

---

## Pages utilitaires

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| `GET` | `/astro` | Aucune | Page Astro Base |
| `GET` | `/cookie` | Aucune | Guide export cookies (Netscape format) |
| `GET` | `/terms` | Aucune | Conditions d'utilisation |
| `GET` | `/n8n` | Aucune | Workflow builder pour automatisations cookie |
| `GET` | `/video` | Aucune | Redirection → `/youtube?html=1` |
| `GET` | `/audio` | Aucune | Redirection → `/mp3?html=1` |
| `GET` | `/12345` | Aucune | Proxy HTTP vers station API locale (port 12345) |
| `GET` | `/credentials/v1` | Aucune | Contexte JSON-LD Verifiable Credentials |
| `GET` | `/ns/v1` | Aucune | Contexte JSON-LD DID namespace |

## Interfaces HTML (routes simples)

Routes servant directement un template HTML, sans logique serveur.

| Méthode | Endpoint | Template | Description |
|---------|----------|----------|-------------|
| `GET` | `/g1` | `g1nostr.html` | Interface MULTIPASS (alias GET de `POST /g1nostr`) |
| `GET` | `/scan` | `scan_new.html` | Scanner QR MULTIPASS / ZenCard |
| `GET` | `/scan_multipass_payment.html` | `scan_multipass_payment.html` | Interface paiement via scan |
| `GET` | `/upload` | `upload2ipfs.html` | Interface upload fichier → IPFS |
| `GET` | `/vocals` | `vocals.html` | Interface enregistrement vocal |
| `GET` | `/vocals-read` | `vocals-read.html` | Lecteur de messages vocaux |
| `GET` | `/cloud` | `cloud.html` | Interface stockage cloud |
| `GET` | `/dev` | `dev.html` | Outils développeur |
| `GET` | `/blog` | `nostr_blog.html` | Blog NOSTR |

---

## Voir aussi

- [how-to/API.NOSTRAuth.readme.md](../how-to/API.NOSTRAuth.readme.md) — NIP-42 côté client et serveur
- [reference/NOSTR_EVENTS_REFERENCE.md](NOSTR_EVENTS_REFERENCE.md) — kinds publiés par UPassport
- [explanation/ANALYTICS.md](../explanation/ANALYTICS.md) — Kind 10600 analytics chiffré
- [explanation/ASYNC_TASKS_NOSTR.md](../explanation/ASYNC_TASKS_NOSTR.md) — bus de tâches NIP-44
