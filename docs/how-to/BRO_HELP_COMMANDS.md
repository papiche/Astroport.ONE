# BRO — Commandes disponibles en DM NOSTR

## Aide, help, commandes

Pour voir les commandes disponibles, envoie : `help`, `aide`, `commandes BRO`, ou `quelles sont les commandes`

BRO répond automatiquement à toute question libre en cherchant dans sa base de connaissance (Qdrant + Ollama).

---

## Commandes texte DM

| Commande | Rôle |
|----------|------|
| `<question libre>` | Réponse IA depuis la base de connaissance |
| `Ma question #1` | Utilise le slot mémoire 1 comme contexte |
| `Ma question #1 #5` | Combine les slots 1 et 5 |

### Mémoire personnelle

| Commande | Rôle |
|----------|------|
| `#rec <texte>` | Mémoriser dans le slot 0 (personnel) |
| `#rec #2 <texte>` | Mémoriser dans le slot 2 (sociétaires) |
| `#rec <texte> #bro <question>` | Mémoriser ET interroger l'IA |
| `#mem` | Voir toutes vos mémoires (tous slots) |
| `#mem #2` | Voir le contenu du slot 2 |
| `#reset` | Effacer toutes vos mémoires |
| `#reset #2` | Effacer uniquement le slot 2 |

### Compétences partagées (Level ≥ 2 — profil atom4love requis)

| Commande | Rôle |
|----------|------|
| `#rec:<skill> <note>` | Contribuer à la mémoire partagée du skill |
| `#mem:<skill>` | Lire la mémoire partagée du skill |
| `#mem:` | Lister tous les skills mémorisés sur ce nœud |
| `#craft <url>` | Décomposer un tutoriel en recette MineLife (WoTx²) |

Exemples :
- `#rec:devops Je maîtrise nginx et TLS`
- `#mem:devops`
- `#craft https://instructables.com/...`

### Badges et IA (niveaux avancés)

| Commande | Niveau requis | Rôle |
|----------|--------------|------|
| `#badge <skill>` | Level 3 — satellite ẐEN | Générer une image de badge skill (ComfyUI) |
| `comfyui_job` | Level 4 — constellation IA | Génération d'image IA avancée |

---

## Niveaux d'accès

| Niveau | Condition | Commandes débloquées |
|--------|-----------|---------------------|
| 0 | Membre enregistré | Questions libres, #rec, #mem, #reset |
| 2 | Profil atom4love créé sur atomic.html | #craft, #rec:<skill>, #mem:<skill> |
| 3 | Souscription satellite ẐEN | #badge |
| 4 | Souscription constellation avec IA | ComfyUI jobs |

Pour créer un profil atom4love (Level 2) : aller sur `atomic.html`, saisir date/heure/lieu de naissance.

---

## Sélection de slots mémoire

Les slots permettent de segmenter ta mémoire personnelle :
- Slot 0 : usage général (défaut)
- Slot 1-9 : usage libre
- Slot 2 : convention pour les notes de sociétaires

Exemple : `Comment optimiser ma station ? #3` → BRO répond en utilisant ton contexte slot 3.

---

## Commandes émises par les applications

Ces commandes arrivent automatiquement depuis les apps UPlanet (pas en tapant du texte) :

| Type | Source | Rôle |
|------|--------|------|
| `udrive` | Application UPlanet | Upload de fichier vers uDRIVE IPFS |
| `vocals` | Application UPlanet | Synthèse vocale / publication audio |
| `webcam` | Application UPlanet | Publication flux webcam |
| `zen_like` | Kind 7 NOSTR | Paiement ẐEN via réaction |
| `love` | cabine-33 / atomic.html | Rencontre ATOM4LOVE (matching phi2x) |
| `bro_ia` | Usage interne | Pipeline IA directe |
