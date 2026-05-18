# MineLife — Guide d'utilisation de l'interface WoTx2

Interface : `UPlanet/earth/minelife.html`

> Pour la philosophie et le "pourquoi", voir [explanation/minelife_wikipedia_wot.md](../explanation/minelife_wikipedia_wot.md).
> Pour les schémas complets des Kinds NOSTR, voir [reference/NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md).

---

## Comment créer un nouveau Permit (recette de craft)

Un **Permit** est la définition d'une compétence — ses ingrédients requis, son niveau, ses ressources de formation associées.

### 1. Ouvrir l'éditeur de craft

- Dans MineLife, cliquer sur **✏️ Éditer** (topbar) pour activer le mode édition
- Puis cliquer sur **⚒ Nouveau craft**

### 2. Remplir la grille WYSIWYG

```
ÉDITEUR — Clic & Drag
┌────────────────────┬──────────────────────────┬──────────────────┐
│   PALETTE          │     GRILLE 3×3           │   RESSOURCES     │
│   (skills dispo)   │                          │                  │
│                    │  linux x1 │docker x1│    │  📄 devops.pdf   │
│  [🐧 linux  x1]   │  ─────────┼─────────┤    │  🎬 tuto.mp4    │
│  [🐋 docker x1]   │           │         │    │                  │
│  [📜 bash   x1]   │  ─────────┼─────────┤    │  [📁 Mes médias] │
│                    │           │         │    │                  │
└────────────────────┴──────────────────────────┴──────────────────┘
```

**Interactions :**
- **Glisser** un skill de la palette → slot de la grille
- **Boutons `+`/`−`** sur un slot → ajuster le niveau requis (1 à 5)
- **Double-clic** sur un slot rempli → vider le slot
- **Glisser** un média depuis "Mes médias" → zone Ressources

### 3. Ajouter des ressources de formation (optionnel)

Cliquer **[📁 Mes médias]** pour ouvrir le navigateur NOSTR du joueur (Kind 21/22/1063/1222/30023).
Glisser un fichier vers la zone Ressources.

### 4. Publier

Cliquer **[☁ Publier]** → publie un Kind 30500 sur le relay strfry.
Si le `d` tag existe déjà (même `d`), l'event est mis à jour (Replaceable Event NIP-33).

---

## Comment importer une URL avec l'IA (Import URL → Craft IA)

L'éditeur de craft intègre un champ **Import URL** :

1. Ouvrir l'éditeur (bouton ⚒ ou "Nouveau craft")
2. Coller une URL (Instructables, Wikipedia, tutoriel…)
3. Cliquer **🤖 IA** → BRO analyse la page et propose automatiquement :
   - Nom du craft
   - Icône
   - Ingrédients (skills + niveaux)
4. Ajuster dans la grille WYSIWYG
5. Cliquer **[☁ Publier]**

**Exemple de réponse BRO :**
```json
{
  "name": "Arduino TV-B-Gone",
  "icon": "📺",
  "ingredients": [
    {"skill": "arduino",        "level": 1},
    {"skill": "electronique_base", "level": 1},
    {"skill": "soudure",        "level": 1}
  ]
}
```

---

## Comment soumettre une demande X1 (Aspiration)

Pour exprimer publiquement qu'on veut apprendre un skill :

1. Dans l'onglet **Atelier**, cliquer sur un skill non certifié
2. Cliquer **📩 Aspirer à ce skill** → publie un Kind 30501
3. Le bouton **📩 Contacter les porteurs** affiche les détenteurs N² du skill
4. Envoyer un DM Kind 4 directement depuis l'interface pour organiser une session

---

## Comment valider un apprenti (émettre une attestation)

**Règle A — Par réaction (3 validations suffisent) :**

1. Dans l'onglet **Atelier**, localiser la demande X1 d'un apprenti (Kind 30501)
2. Cliquer **👍 Valider** → publie un Kind 7 avec `content: "+"`
3. Quand 3 pairs distincts ont validé, l'apprenti peut auto-signer son Kind 30503

**Règle B — Par adoubement direct (si vous êtes X1+ du skill) :**

1. Cliquer sur la demande Kind 30501 de l'apprenti
2. Cliquer **🏅 Adouber directement** → publie un Kind 30502
3. L'apprenti peut immédiatement auto-signer son Kind 30503

---

## Comment ajouter une ressource dans l'onglet Formation

### Depuis l'interface (Mode Édition)

1. Activer **✏️ Éditer** (topbar)
2. Aller dans l'onglet **Formation**
3. Cliquer **[📁 Mes médias]** → navigateur des médias NOSTR du joueur
4. Sélectionner un fichier → glisser vers la zone Formation du skill
5. → publie automatiquement un Kind 30504 avec `["r", "/ipfs/CID", "type"]`

### En CLI

```bash
python3 tools/nostr_node_intercom.py publish \
    --nsec "$NSEC" --kind 30504 \
    --tags '[["d","training_linux_<timestamp>"],
             ["t","linux"],["t","formation"],
             ["r","/ipfs/QmXxx.../guide.pdf","document"],
             ["title","Guide Linux Debian"]]' \
    --content '{"skill":"linux","resource_type":"document"}' \
    --relays "ws://localhost:7777"
```

Puis indexer pour BRO :
```bash
./tools/knowledge_index.sh --index-nostr
```

---

## Comment révoquer une compétence

Dans l'onglet **Mes Compétences** :

1. Localiser le Kind 30503 à révoquer
2. Cliquer **Révoquer** → publie un Kind 5 (NIP-09)

---

## Flux complet : de la découverte à la certification

```
[Explorer l'Atelier]
Parcourir les crafts disponibles (Kind 30500) sur le relay local

       ↓

[Aspirer X1]
Kind 30501 auto-signé → contacter les porteurs via DM Kind 4

       ↓

[Session de craft]
Règle A : 3× Kind 7 `+` de pairs distincts
Règle B : 1× Kind 30502 d'un pair X1+

       ↓

[Auto-signer le certificat]
Kind 30503 publié → visible dans Mes Compétences
→ débloque les crafts composites qui requièrent ce skill
```

---

## Fichiers de référence

| Fichier | Rôle |
|---------|------|
| `UPlanet/earth/minelife.html` | Interface principale MineLife |
| `UPlanet/earth/minelife.js` | Widget crafting (`MineLife.init`) |
| `Astroport.ONE/tools/oracle_init_captain_wotx2.sh` | Bootstrap Kind 30500 capitaines |
| `Astroport.ONE/RUNTIME/ORACLE.refresh.sh` | Émet Kind 30503 Oracle (cron) |
| `Astroport.ONE/IA/bro_dm_daemon.sh` | Daemon Kind 4 BRO |
| `Astroport.ONE/tools/knowledge_index.sh` | Index vectoriel Qdrant |

---

## Voir aussi

- [KNOWLEDGE_EMBEDDINGS.md](KNOWLEDGE_EMBEDDINGS.md) — indexer les ressources dans Qdrant
- [tutorials/setup_learning_hub.md](../tutorials/setup_learning_hub.md) — configurer sa station hub
- [explanation/minelife_wikipedia_wot.md](../explanation/minelife_wikipedia_wot.md) — la philosophie WoT
- [reference/NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md) — spec Kind 30500–30504
