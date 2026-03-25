# 📋 AUTOfollow.rules.md - Système de Follow Automatique NOSTR : Liaisons et Suivi

## 1. 🔗 Liaisons entre les Clefs (Web of Trust)

Le système UPlanet ne repose pas sur une clef unique, mais sur un **faisceau de clefs interdépendantes** qui lient l'identité physique, sociale et économique.

### A. Le Triptyque de l'Utilisateur (MULTIPASS)
*   **Clef Nostr (NSEC/NPUB) ↔ Email :** La clef sociale est dérivée de façon déterministe par le couple Salt/Pepper lié à l'email.
*   **Clef Nostr ↔ Wallet Ğ1 (MULTIPASS) :** Le wallet de "revenu" (usage quotidien) est lié à l'identité Nostr pour permettre les paiements par "Like" (Kind 7).
*   **Clef Nostr ↔ ZEN Card (G1PUB) :** La clef sociale porte dans ses métadonnées (Tags `i`) la preuve de possession de la ZEN Card (Capital).
*   **Clef Nostr ↔ Localisation (UMAP) :** Chaque message est ancré géographiquement via un tag `g` (lat, lon), liant l'identité à un bot de zone.

### B. Les Clefs de la Station (Le Capitaine)
*   **IPFSNODEID ↔ Clef SSH :** Grâce au script `Ylevel.sh`, l'identité réseau (IPFS) est la même que l'identité d'accès machine (SSH).
*   **IPFSNODEID ↔ Capitaine :** Le premier MULTIPASS créé sur la station devient le "Capitaine" et signe les rapports de santé économique (Kind 30850).

### C. Les Clefs Système (L'infrastructure)
*   **UPLANETNAME_G1 (L'Oracle) :** Cette clef est le "Cœur de la Constellation". Elle signe la configuration partagée (Kind 30800) et sert de source primale pour tous les wallets.
*   **Bots Géographiques (UMAP/SECTOR/REGION) :** Des clefs Nostr générées pour chaque coordonnée GPS (ex: `UPlanet + Lat + Lon`). Ils servent de journaux de bord locaux.

---

## 🛰️ AUTOfollow.rules.md : Système de Suivi Automatique

Le système de **follow automatique** assure la propagation de l'information dans l'essaim (Swarm) sans intervention manuelle, créant une "Mémoire N²" (Nostr + Nœuds).

### Règle 1 : Le Capitaine suit ses Passagers
*   **Action :** Le script `DRAGON_p2p_ssh.sh` force le compte du Capitaine à suivre tous les **HEX** (pubkeys) présents localement sur la station.
*   **But :** Permettre au Capitaine de voir l'activité de sa station et de relayer leurs messages.

### Règle 2 : Les Passagers suivent le Capitaine
*   **Action :** Lors de la création (`make_NOSTRCARD.sh`) ou du rafraîchissement hebdomadaire (`NOSTRCARD.refresh.sh`), chaque MULTIPASS suit automatiquement la clef **CAPTAINHEX**.
*   **But :** Recevoir les annonces de maintenance, les alertes et les informations de la station de rattachement.

### Règle 3 : Alignement vers UPlanet ORIGIN
*   **Action :** Si la station est en mode ẐEN (privée), le compte de l'infrastructure UPlanet suit automatiquement l'identité **UPlanet ORIGIN**.
*   **But :** Maintenir un lien avec la constellation mère pour les mises à jour et la gouvernance globale.

### Règle 4 : Le "Follow" Géographique (Ancrage UMAP)
*   **Action :** Lorsqu'un utilisateur publie un média ou un message avec des coordonnées GPS, le filtre `1.sh` ou `21.sh` peut déclencher un suivi automatique du **Bot UMAP** correspondant.
*   **But :** Créer des communautés locales automatiques. Si vous postez à Toulouse (43.60, 1.44), vous commencez à suivre le journal de Toulouse.

### Règle 5 : La Solidarité entre Capitaines (Swarm Awareness)
*   **Action :** Le script `DRAGON_p2p_ssh.sh` scanne les événements Nostr de type **Kind 30850** (Rapports économiques). Le Capitaine suit tous les autres Capitaines du même Swarm (`swarm_id`).
*   **But :** Permettre l'accès SSH P2P entre machines de confiance pour le support technique mutuel.

---

## 🛡️ Rôle du Relai (`strfry`) dans la Validation

Les scripts `process.sh` et `all_but_blacklist.sh` agissent comme des douaniers utilisant ces liaisons :

1.  **Whitelist Dynamique :** Seules les clefs ayant un compte local, appartenant au Swarm, ou présentes dans `amisOfAmis.txt` peuvent écrire sur le relai.
2.  **Gestion des Intrus :** Le filtre `1.sh` détecte les "Visitors" (clefs inconnues). Il les autorise pour 3 messages tout en envoyant un bot (UMAP 0.00,0.00) leur demander de s'enregistrer, avant de les blacklister.
3.  **Liaison Like-to-Pay :** Le filtre `7.sh` intercepte les réactions. S'il voit un `+` ou un emoji coeur entre deux clefs liées à UPlanet, il déclenche un virement Ğ1 réel via `PAYforSURE.sh`.

### Résumé du Flux de Confiance
`Email` ➔ `MULTIPASS (Nostr)` ➔ `ZEN Card (Ğ1)` ➔ `Station (Capitaine)` ➔ `UMAP (Géo-Local)` ➔ `Swarm (Constellation)`
