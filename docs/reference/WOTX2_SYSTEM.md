# WoTx2 — Toiles de Confiance Décentralisées

**Version** : 2.1 — Architecture Duale Oracle + P2P + MineLife Interface\
**Mise à jour** : Mai 2026\
**Statut** : Production\
**License** : AGPL-3.0

> Pour la description complète des kinds NOSTR, clés, schémas et flows, voir [**MINELIFE.md**](../how-to/MINELIFE.md).

***

## Architecture Duale

WoTx2 fonctionne en deux modes complémentaires :

* **Mode Oracle** : Kind 30503 signé par `UPLANETNAME_G1` — émis par `ORACLE.refresh.sh`
* **Mode P2P** : Kind 30503 auto-signé par le titulaire — calculé localement (TrocZen, MineLife)

Les deux modes coexistent sur le même relay NOSTR. Voir [MINELIFE.md §2](../how-to/MINELIFE.md) pour le format exact de chaque Kind.

***

## Compétences Capitaines (Seeds)

Initialisées par `oracle_init_captain_wotx2.sh` (appelé depuis `install.sh`) :

| Skill Tag   | Permit X1             |
| ----------- | --------------------- |
| `astroport` | `PERMIT_ASTROPORT_X1` |
| `linux`     | `PERMIT_LINUX_X1`     |
| `bash`      | `PERMIT_BASH_X1`      |
| `python`    | `PERMIT_PYTHON_X1`    |
| `docker`    | `PERMIT_DOCKER_X1`    |
| `dart`      | `PERMIT_DART_X1`      |
| `flutter`   | `PERMIT_FLUTTER_X1`   |
| `nostr`     | `PERMIT_NOSTR_X1`     |
| `ipfs`      | `PERMIT_IPFS_X1`      |
| `git`       | `PERMIT_GIT_X1`       |

***

## Règles de Progression

* **Règle A** : 3 réactions Kind 7 `+` distinctes → auto-signer Kind 30503
* **Règle B** : 1 Kind 30502 d'un pair niveau X1+ → montée directe
* **Règle C** (Oracle) : `ORACLE.refresh.sh` émet Kind 30503 Oracle quand seuil `min_attestations` atteint

***

## Agnosticisme sur les Clés

Un Kind 30503 est valide quel que soit son signataire (Oracle, auto-signé, capitaine). Vérification dans l'ordre :

```
Attester valide pour PERMIT_SKILL_Xn ?
  ├─ Oracle VC  : tag ["l", "PERMIT_SKILL_Xm", "permit_type"] (m ≥ n)
  ├─ TrocZen P2P: pubkey = attester + tag ["d", "PERMIT_SKILL_Xm"] (m ≥ n)
  └─ Folksonomie: pubkey = attester + tag ["t", skill] + tag ["level"] ≥ n
```

***

## Bootstrap Capitaine

À la fin de `install.sh` :

1. `emit_skill.sh` publie Kind 30503 x1 pour les compétences détectées (`bash`, `linux-admin`, `ipfs`, `nostr`, `astroport-install`)
2. Un lien `install_craft.html?session_cid=QmXxx` est affiché — le capitaine y joint ses preuves et co-signe ses skills
3. `oracle_init_captain_wotx2.sh` crée les Kind 30500 des compétences capitaines (seeds Oracle)
4. La progression continue dans `minelife.html` (explorer, crafts, formation)

***

## Interface

| Interface    | Fichier                    | Description                                                                                                                                      |
| ------------ | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **MyCraft**  | `earth/install_craft.html` | Activation des compétences post-installation — joindre preuve + émettre Kind 30503/30504                                                         |
| **Skills**   | `earth/skills.html`        | Nuage de tags animé (p5.js) — 4 vues (global / MULTIPASS / Oracle Nœud / Oracle Constellation), switch source API↔Relay, sélecteur constellation |
| **MineLife** | `earth/minelife.html`      | Dashboard principal — crafting + formation + BRO                                                                                                 |
| **TrocZen**  | Flutter app                | Mobile P2P — Règle A/B, synthèse, WoTx2 offline                                                                                                  |

### Modules JS partagés (WoTx2)

| Module            | Fichier           | API publique                                                                                                          |
| ----------------- | ----------------- | --------------------------------------------------------------------------------------------------------------------- |
| **SkillCloud**    | `earth/skills.js` | `SkillCloud.init(opts)` — widget p5.js Kind 30503/30504, 4 vues, découverte oracle via tag `l permit_type`            |
| **RelaySelector** | `earth/relay.js`  | `RelaySelector.init(opts)`, `isLocal(ws)`, `toApiBase(ws)` — peuple `<select>` depuis constellation (myRELAY + SWARM) |

### Architecture duale skills.html (source switch)

```
Mode "API + Relay" (défaut, relay local) :
  Oracle pubkeys  ← GET /api/skill/oracles  (UPassport)
  Médias Kind 30504 ← GET /api/skill/media/{skill}  (UPassport)
  Bulles Kind 30503 ← WebSocket relay  (SkillCloud widget)

Mode "Relay seul" (relay distant ou hors ligne) :
  Oracle pubkeys  ← découverte relay (tag ["l","PERMIT_SKILL_Xn","permit_type"])
  Médias Kind 30504 ← WebSocket relay (même relay sélectionné)
  Bulles Kind 30503 ← WebSocket relay  (SkillCloud widget)
```

### Oracles WoTx2

| Clé                  | Fichier                        | Rôle                                                      |
| -------------------- | ------------------------------ | --------------------------------------------------------- |
| Oracle Nœud          | `~/.zen/game/secret.nostr`     | Clé NOSTR locale du nœud (chaque station)                 |
| Oracle Constellation | `~/.zen/game/uplanet.G1.nostr` | Clé du 1er bootstrap IPFS — partagée par la constellation |

Les événements oracle Kind 30503 portent le tag `["l", "PERMIT_SKILL_Xn", "permit_type"]`.\
Endpoint API : `GET /api/skill/oracles` → `{ "node": "hex64...", "constellation": "hex64..." }`.\
En mode relay seul, les pubkeys oracle sont découvertes depuis ce tag (sans API).

***

## Kind 30504 — Ressource de formation

Spec complète dans [NOSTR\_EVENTS\_REFERENCE.md](NOSTR_EVENTS_REFERENCE.md).

**Tags obligatoires :** `d` (identifiant), `t` (skill), `r` (CID IPFS + type).

**Payload Qdrant (collection `knowledge`) :**

```json
{
  "cid":        "QmXxx...",
  "title":      "Guide Docker",
  "skill":      "docker",
  "author_hex": "<pubkey_hex_64>",
  "event_id":   "<event_hex_64>",
  "kind":       30504,
  "created_at": 1748000000
}
```

**Structure Nextcloud pour l'indexation (`--index-dir`) :**

```
~/nextcloud/Astroport/
├── linux/          ← skill = "linux"
│   ├── guide.md
│   └── debian.pdf
├── docker/         ← skill = "docker"
│   └── compose.md
└── ipfs/           ← skill = "ipfs"
    └── kubo.pdf
```

Le nom du sous-dossier est la valeur du tag `t` dans le Kind 30504 généré.

***

## Modèles Ollama — Embedding vs Génération

| Rôle                              | Modèle              | Taille   |
| --------------------------------- | ------------------- | -------- |
| **Embedding** (indexation Qdrant) | `nomic-embed-text`  | \~274 Mo |
| **Génération BRO skill**          | `gemma3:latest`     | \~3.3 Go |
| **Génération code**               | `qwen2.5-coder:14b` | \~9 Go   |

***

## TTL inter-NODE (NIP-40) — canaux `nostr_node_intercom.py`

| Canal            | TTL      | Raison                                       |
| ---------------- | -------- | -------------------------------------------- |
| `bro_ia`         | 3 600 s  | Commande traitée immédiatement ou abandonnée |
| `comfyui_job`    | 7 200 s  | Fenêtre GPU max                              |
| `comfyui_result` | 3 600 s  | Récupération avant expiration                |
| `udrive`         | 86 400 s | Sync fichier moins urgent                    |
| `zen_like`       | 86 400 s | Paiement relayé dans la journée              |

***

## Objets & Ressources (Kind 30505 / 1505)

WoTx² modélise non seulement les **compétences** (Kind 30503) mais aussi les **objets physiques et logiques** que les MULTIPASS possèdent ou partagent.

### Quatre régimes de quantité

| `quantity_type` | Modèle                            | Exemples                             |
| --------------- | --------------------------------- | ------------------------------------ |
| `discrete`      | Stock comptable (qty±)            | Câbles XLR, composants, filtres      |
| `capacity`      | Slots simultanés (dur seule mute) | Cabane (8 places), studio (2 postes) |
| `durability`    | Objet unique (qty=1, dur mute)    | RPi, vélo, table de mixage           |
| `infinite`      | Communs immatériels (immuable)    | Documentation, recette, partition    |

### Cycle de vie d'un objet

```
Kind 30505 (état courant)     ←── remplace le précédent à chaque mutation
Kind 1505  (journal append)   ←── chaque delta : acquisition / usure / maintenance
Kind 1500  (log de session)   ←── chaque exécution de craft en temps réel
```

La `durability` (0–100) est gouvernée par trois drivers : usure par usage, dégradation passive, et bonus d'attention (un bien utilisé régulièrement se dégrade moins vite qu'un bien abandonné).

> Spec complète : [**KIND\_30505\_OBJECTS.md**](KIND_30505_OBJECTS.md)

***

## Médiation & Justice (Kind 1984 / 30506 / 1506)

Quand un MULTIPASS utilise un objet partagé sans le niveau WoT requis, ou lorsqu'un désaccord survient, le protocole de médiation WoT-based est déclenché.

### Déclenchement

Un Kind 1984 avec `["report-type", "friction"]` active le pipeline :

```
Kind 1984 (friction)
  └► relay 1984.sh → justice_cases.log + N1Mediation.sh (async)
       └► Kind 30506 créé (status=N1_ouvert, signé oracle)
            ├► N1 notifié (contacts communs via amisOfAmis.txt)
            │    └► Kind 1506 (vote_amiable) publiés par médiateurs
            ├► [résolution] 30506 → status=N1_résolu + Kind 7 réparation
            └► [escalade]   30506 → status=N2_ouvert + panel 5 membres N2
```

### Seuils

| Montant (ẐEN) | Circuit                              | Quorum                    |
| ------------- | ------------------------------------ | ------------------------- |
| ≤ 10 ẐEN      | N1 amiable (cercle direct Kind 3)    | Majorité contacts communs |
| > 10 ẐEN      | N2 arbitrage formel (amisOfAmis.txt) | 5 membres titrés          |
| > 50 ẐEN      | Vote constellation élargi            | Assemblée constellation   |

### Status du dossier

| Valeur      | Signification                  |
| ----------- | ------------------------------ |
| `N1_ouvert` | Médiation amiable en cours     |
| `N1_résolu` | Résolution amiable atteinte    |
| `N2_ouvert` | Escalade vers arbitrage formel |
| `N2_résolu` | Verdict formel rendu           |
| `classé`    | Dossier clos sans suite        |

> Spec complète : [**KIND\_30506\_JUSTICE.md**](KIND_30506_JUSTICE.md)\
> NIP extension : [**nostr-nips/56-friction-mediation-extension.md**](https://github.com/papiche/Astroport.ONE/blob/master/nostr-nips/56-friction-mediation-extension.md)

***

## Filtre de domaines (skills.html)

L'interface `skills.html` propose un filtre par domaine pour éviter la saturation visuelle du nuage de compétences. Le filtre est **client-side** (aucun aller-retour relay).

### API publique SkillCloud (ajouts)

```javascript
cloud.setDomainFilter(['linux', 'docker', 'python']); // n'afficher que ces skills
cloud.getDomainFilter();                               // → ['linux', 'docker', 'python'] | null
```

### Domaines prédéfinis (DOMAIN\_SKILLS)

| Chip        | Exemples de skills inclus                         |
| ----------- | ------------------------------------------------- |
| Numérique   | linux, docker, nostr, ipfs, python, rust…         |
| Artisanat   | menuiserie, soudure, céramique, lutherie…         |
| Nature      | permaculture, apiculture, semences, botanique…    |
| Culture     | musique, chant, photographie, danse, théâtre…     |
| Habitat     | maçonnerie, charpente, isolation, cob, adobe…     |
| Agriculture | maraîchage, élevage, viticulture, fromage…        |
| Santé       | phytothérapie, premiers-secours, yoga, nutrition… |

Cliquer sur un chip filtre instantanément les bulles p5.js. Cliquer sur « Tous » remet `_domainSkillSet = null`.

***

## Données de démo (6 personas)

Le script `tools/demo_wotx2_seed.sh` génère un jeu complet de données NOSTR pour 6 personas couvrant 6 domaines :

| Persona    | Domaine              | Skills clés                                      | Objets                                     |
| ---------- | -------------------- | ------------------------------------------------ | ------------------------------------------ |
| **toto**   | Numérique / son      | sound-spot, linux, bash, ipfs                    | RPi Zero 2W, BT Speaker                    |
| **coucou** | Numérique            | nostr, python, git, docker                       | Câbles XLR, Documentation                  |
| **jean**   | Transport / mobilité | permis-conduire-vehicule (x1), mécanique         | Voiture partagée                           |
| **marie**  | Nature / agriculture | permaculture, apiculture, semences, maraîchage   | Ruche, Jardin semences, Guide permaculture |
| **ali**    | Culture / son        | musique, chant, son, sound-spot                  | Table de mixage, Studio mobile             |
| **sophie** | Santé                | phytothérapie, premiers-secours, yoga, nutrition | Herbier, Tisanes                           |

Les 6 personas partagent des objets, co-signent des crafts et s'attestent mutuellement, couvrant l'ensemble des fonctionnalités WoTx² (crafting social, médiation, progression).

***

## Références

* [**NOSTR\_EVENTS\_REFERENCE.md**](NOSTR_EVENTS_REFERENCE.md) — Table exhaustive kinds UPlanet
* [**KIND\_30505\_OBJECTS.md**](KIND_30505_OBJECTS.md) — Spec objets : quantity model, quorum, repairability, lifecycle
* [**KIND\_30506\_JUSTICE.md**](KIND_30506_JUSTICE.md) — Spec médiation : dossier, actes, assurance mutualiste
* [**how-to/MINELIFE.md**](../how-to/MINELIFE.md) — Utiliser l'interface
* [**how-to/REPORT\_FRICTION.md**](../how-to/REPORT_FRICTION.md) — Déclarer une friction et suivre la médiation
* [**how-to/KNOWLEDGE\_EMBEDDINGS.md**](../how-to/KNOWLEDGE_EMBEDDINGS.md) — Indexer les ressources
* [**explanation/minelife\_wikipedia\_wot.md**](../explanation/minelife_wikipedia_wot.md) — Philosophie WoT
* [**explanation/WOTX2\_MEDIATION.md**](../explanation/WOTX2_MEDIATION.md) — Philosophie de l'assurance mutualiste WoT
* [**tutorials/WOTX2\_DEMO\_SCENARIO.md**](../tutorials/WOTX2_DEMO_SCENARIO.md) — Scénario de démo complet (6 personas)
* `Astroport.ONE/tools/oracle_init_captain_wotx2.sh` — Bootstrap capitaines
* `Astroport.ONE/RUNTIME/ORACLE.refresh.sh` — Oracle quotidien
* `Astroport.ONE/tools/demo_wotx2_seed.sh` — Seed 6 personas (toto/coucou/jean/marie/ali/sophie)
* `Astroport.ONE/admin/dashboard.JUSTICE.manager.sh` — CLI admin médiation
* `TrocZen/docs/WOTX2_SYSTEM.md` — Architecture P2P TrocZen v3.6
* `nostr-nips/42-oracle-permits-extension.md` — Spec NOSTR permits
* `nostr-nips/56-friction-mediation-extension.md` — Spec NIP extension médiation WoT
