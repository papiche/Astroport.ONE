# Tutoriel — Scénario de démo WoTx² complet (6 personas)

Ce tutoriel suit les 6 personas du jeu de démo (`tools/demo_wotx2_seed.sh`) à travers les fonctionnalités clés du système WoTx² : compétences, objets, crafting social, et médiation.

---

## Les 6 personas

| Persona | Domaine | Skills | Rôle dans le scénario |
|---------|---------|--------|----------------------|
| **toto** | Numérique / son | sound-spot, linux, bash, ipfs | Technicien réseau — initie le craft |
| **coucou** | Numérique | nostr, python, git, docker | Développeur — co-opère + documente |
| **jean** | Transport | permis-conduire-vehicule (x1) | Propriétaire voiture — partie dans la friction |
| **marie** | Nature | permaculture, apiculture, semences | Jardinière — partage ses ressources |
| **ali** | Culture / son | musique, chant, son | Musicien — rejoint le craft sound-spot |
| **sophie** | Santé | phytothérapie, premiers-secours, yoga | Soignante — atteste les compétences santé |

---

## Acte 1 — Installation du jeu de démo

```bash
cd Astroport.ONE
bash tools/demo_wotx2_seed.sh
```

Le script publie sur le relay local (ws://127.0.0.1:7777) :
- 6 × Kind 30503 (compétences attestées pour chaque persona)
- 10 × Kind 30505 (objets partagés : RPi, voiture, ruche, table de mixage…)
- 4 × Kind 30500 (recettes de craft)
- 4 × Kind 30503 croisés (attestations inter-domaines)

Vérification rapide :

```bash
cd ~/.zen/strfry && ./strfry scan '{"kinds":[30503],"limit":20}' | jq '.tags[0]'
```

---

## Acte 2 — Exploration des compétences (skills.html)

Ouvrez `[UPlanet/earth/skills.html](http://127.0.0.1:54321/earth/skills.html)` dans votre navigateur.

### 2.1 Vue globale

Le nuage p5.js affiche toutes les compétences attestées. Les bulles les plus grandes correspondent aux skills les plus attestés collectivement.

### 2.2 Filtre par domaine

Cliquez sur les chips de domaine pour voir :
- **Numérique** → bulles linux, bash, docker, nostr, python, sound-spot
- **Nature** → bulles permaculture, apiculture, semences, maraîchage
- **Culture** → bulles musique, chant, son
- **Santé** → bulles phytothérapie, premiers-secours, yoga

### 2.3 Vue MULTIPASS

Cliquez sur la bulle **"toto"** (ou entrez son npub dans le sélecteur) → seules ses compétences s'affichent.

### 2.4 Source API vs Relay

Basculez en mode **Relay seul** pour voir les Kind 30503 directement depuis le relay sans passer par l'API UPassport.

---

## Acte 3 — Craft social : atelier son

**Contexte** : toto veut monter un point d'accès sound-spot. Il a besoin de :
- Son RPi Zero 2W (`rpi-zero2w-toto`)
- La BT Speaker de zicmama (`bt-speaker-toto`)
- ali pour la partie musicale

**Recette** : `atelier-son-sound-spot` (Kind 30500)

```
Opérateurs requis : 2
  Rôle 0 : PERMIT_SOUND_SPOT_INSTALL_X1 (toto)
  Rôle 1 : PERMIT_MUSIQUE_X1 (ali)
Objets consommés : rpi-zero2w-toto (durability -5)
Objet produit : Kind 30503 PERMIT_SOUND_SPOT_X2 pour ali
```

Depuis minelife.html → onglet **Craft** → rechercher "sound-spot" → cliquer "Démarrer craft".

UI a développer:
toto scanne le QR de son MULTIPASS, ali scanne le sien → le craft est co-signé.


**Résultat** :
- Kind 1500 (log session) publié
- Kind 1505 (delta durability -5 sur le RPi) publié
- Kind 30503 PERMIT_SOUND_SPOT_X2 émis pour ali

---

## Acte 4 — Marie partage son herbier

marie publie son herbier (`herbier-marie`, Kind 30505 type `durability`) avec :

```json
["skill_required", "phytotherapie:x1"]
["min_operators", "1"]
["doc", "ipfs://QmHerbierMarie"]
```

sophie, qui a `phytotherapie:x1`, peut utiliser l'herbier librement. Elle publie un Kind 1505 après usage :

```json
{
  "kind": 1505,
  "content": "{\"delta_durability\":-2,\"durability_after\":98,\"reason\":\"consultation pour atelier tisanes 2026-05-31\"}",
  "tags": [
    ["d", "herbier-marie"],
    ["t", "degradation"],
    ["delta_durability", "-2"],
    ["durability_after", "98"]
  ]
}
```

L'herbier de marie reste en excellent état — l'attention régulière de sophie ralentit la dégradation passive.

---

## Acte 5 — La friction avec la voiture

**Contexte** : jean possède une voiture partagée (`voiture-partagee-5-places-jean`) avec `skill_required: permis-conduire-vehicule:x2`. coucou emprunte la voiture mais n'a que x1 (auto-proclamé).

Un problème mineur survient lors du retour. coucou déclare une friction.

### 5.1 Déclaration (Kind 1984)

```bash
# coucou déclare la friction
nostr_node_intercom.py send --kind 1984 \
  --tags '[
    ["report-type", "friction"],
    ["p", "<jean_hex>"],
    ["reason", "Usage voiture sans permis x2 WoT validé"],
    ["object", "voiture-partagee-5-places-jean"],
    ["skill", "permis-conduire-vehicule:x2"],
    ["friction-amount", "5"]
  ]' \
  --content "Utilisation de la voiture partagée sans le permis x2 requis."
```

### 5.2 Ouverture du dossier

Le relay 1984.sh détecte et crée automatiquement un Kind 30506 :

```bash
./admin/dashboard.JUSTICE.manager.sh pending
```

### 5.3 Médiation N1 — toto et sophie votent

toto et sophie sont contacts communs de jean ET coucou. Ils reçoivent une notification et votent :

```bash
# toto vote +1 (pour l'indemnisation)
nostr_node_intercom.py send --kind 1506 \
  --tags '[["d","friction-coucou1-jean56-1748736000"],["t","vote_amiable"]]' \
  --content '{"action":"vote_amiable","vote":"+1","note":"Permis x2 requis non validé, 5 ẐEN approprié"}'
```

```bash
# sophie vote +1
nostr_node_intercom.py send --kind 1506 \
  --tags '[["d","friction-coucou1-jean56-1748736000"],["t","vote_amiable"]]' \
  --content '{"action":"vote_amiable","vote":"+1","note":"Accord sur 5 ẐEN"}'
```

### 5.4 Résolution

Majorité atteinte (2/2 votes positifs, montant ≤ 10 ẐEN) :

```bash
./admin/dashboard.JUSTICE.manager.sh resolve friction-coucou1-jean56-1748736000 \
  "Résolution amiable : 5 ẐEN versés, jean s'engage à valider son permis x2"
```

coucou reçoit 5 ẐEN via Kind 7 depuis la TRÉSORERIE station.

### 5.5 Vérifier l'état final

```bash
./admin/dashboard.JUSTICE.manager.sh show friction-coucou1-jean56-1748736000
./admin/dashboard.JUSTICE.manager.sh list-acts friction-coucou1-jean56-1748736000
./admin/dashboard.JUSTICE.manager.sh stats
```

---

## Acte 6 — Attestations croisées inter-domaines

Le scénario montre comment les compétences traversent les domaines :

- **toto atteste ali** sur `sound-spot` (numérique → culture)
- **jean atteste marie** sur `git` (transport → nature) — marie documente ses pratiques
- **sophie atteste coucou** sur `nutrition` (santé → numérique) — coucou crée une app nutrition
- **marie atteste jean** sur `permaculture` (nature → transport) — jean s'intéresse à l'agroforesterie

Ces attestations croisées renforcent la cohésion de la WoT et montrent que les domaines ne sont pas des silos.

---

## Dashboard de synthèse

```bash
# Vue d'ensemble WoTx²
./admin/dashboard.WOTX2.manager.sh stats

# Objets partagés
./admin/dashboard.WOTX2.manager.sh list-objects

# Compétences par persona
./admin/dashboard.WOTX2.manager.sh skills toto

# Dossiers justice
./admin/dashboard.JUSTICE.manager.sh stats
./admin/dashboard.JUSTICE.manager.sh browse
```

---

## Ce que ce scénario illustre

| Fonctionnalité | Acte |
|---------------|------|
| Nuage de compétences (SkillCloud) | 2 |
| Filtre de domaines (client-side) | 2 |
| Crafting social (multi-opérateurs) | 3 |
| Objets physiques + durability | 4 |
| Transactions Kind 1505 | 4 |
| Déclaration de friction (Kind 1984) | 5 |
| Médiation N1 (votes Kind 1506) | 5 |
| Résolution + paiement Kind 7 | 5 |
| Attestations inter-domaines | 6 |

---

## Références

- **[reference/WOTX2_SYSTEM.md](../reference/WOTX2_SYSTEM.md)** — Architecture complète
- **[reference/KIND_30505_OBJECTS.md](../reference/KIND_30505_OBJECTS.md)** — Spec objets
- **[reference/KIND_30506_JUSTICE.md](../reference/KIND_30506_JUSTICE.md)** — Spec médiation
- **[how-to/REPORT_FRICTION.md](../how-to/REPORT_FRICTION.md)** — Guide déclaration friction
- **[explanation/WOTX2_MEDIATION.md](../explanation/WOTX2_MEDIATION.md)** — Philosophie
- `tools/demo_wotx2_seed.sh` — Script de seed (6 personas)
- `admin/dashboard.WOTX2.manager.sh` — CLI admin WoTx²
- `admin/dashboard.JUSTICE.manager.sh` — CLI admin médiation
