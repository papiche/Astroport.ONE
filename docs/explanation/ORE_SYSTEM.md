# Le Système ORE de UPlanet : Un Cadastre Écologique Décentralisé

Le système ORE (Obligations Réelles Environnementales) intègre des engagements écologiques vérifiables à des parcelles géographiques (UMAP) en utilisant des identités décentralisées (DID) sur le réseau Nostr. Il crée ainsi un "cadastre écologique" mondial, où la protection de l'environnement devient une activité économiquement valorisée.

## Concepts Clés

*   **UMAP (Universal Map)** : Une cellule géographique de 0.01° x 0.01° (environ 1,2 km²), qui possède sa propre identité numérique.
*   **DID (Identité Décentralisée)** : Chaque UMAP possède un identifiant unique `did:nostr:<clé_publique_hex>`, lui permettant d'avoir un profil, de posséder un portefeuille et de publier des informations sur Nostr.
*   **Contrat ORE** : Un engagement environnemental (ex: "maintenir 80% de couverture forestière") attaché au DID d'une UMAP.
*   **Récompense Ẑen** : La validation du respect d'un contrat ORE déclenche une récompense en Ẑen, la monnaie de l'écosystème UPlanet.
*   **Inventaire Participatif** : Via `plantnet.html`, les citoyens photographient et inventorient les éléments de leur territoire (🌱 plantes, 🐛 insectes, 🦊 animaux, 🔧 équipements, 🏠 lieux). Chaque observation génère un contrat de maintenance et alimente le `diversity_score` de l'UMAP.

## Implémentation : Comment ça marche ?

Le système ORE est une extension du système d'identité de UPlanet. Il ne crée pas de nouveaux mécanismes complexes mais s'appuie sur les outils existants.

### 1. Identité Numérique des Parcelles (UMAP DID)

Chaque parcelle UMAP se voit attribuer une paire de clés Nostr, tout comme un utilisateur humain. Cela permet de :
*   Générer un DID unique : `did:nostr:<clé_hex>`.
*   Publier des informations sur le réseau Nostr.
*   Détenir un portefeuille de cryptomonnaie (Ğ1 / Ẑen).

### 2. Le Contrat ORE dans le Document DID

Les informations du contrat ORE sont intégrées directement dans le document DID de l'UMAP. Ce document est un simple fichier JSON, rendu public et vérifiable sur Nostr.

**Exemple de structure du document DID d'une UMAP :**
```json
{
  "@context": [
    "https://www.w3.org/ns/did/v1",
    "https://w3id.org/ore/v1"
  ],
  "id": "did:nostr:...",
  "type": "UMAPGeographicCell",
  "geographicMetadata": {
    "coordinates": {"lat": 43.60, "lon": 1.44}
  },
  "environmentalObligations": {
    "oreContract": {
      "contractId": "ORE-2025-001",
      "description": "Maintenir 80% de couverture forestière",
      "provider": "did:nostr:...", // DID de l'entité qui vérifie
      "reward": "10" // Montant en Ẑen
    },
    "verificationStatus": "verified",
    "lastVerification": "2025-10-29T10:00:00Z"
  }
}
```

**NOSTR Event Kinds utilisés par le système ORE :**
- **30800** : DID Documents UMAP avec données de diversité attachées (NIP-101)
- **30023** : Contrats de maintenance (Blog articles avec image et markdown)
- **30312** : ORE Meeting Space (Persistent Geographic Space)
- **30313** : ORE Verification Meeting (scheduled meetings for compliance verification)
- **30009, 8, 30008** : Badges NIP-58 (pour matérialiser les compétences ORE validées)

**Fichier de données locales :**
- **ore_biodiversity.json** : Stockage local de toute la diversité inventoriée (plantes, insectes, animaux, objets, lieux, personnes)

**⚠️ Important - Canonisation JSON (RFC 8785) :**
Tous les événements NOSTR contenant du JSON (tags, contenu) sont canonisés selon RFC 8785 (JCS) avant signature pour garantir la cohérence des signatures cryptographiques. Cette canonisation est appliquée automatiquement dans `ore_system.py` via la fonction `canonicalize_json()`.

### 3. Système de Diversité Étendu (ore_biodiversity.json)

Le système ORE maintient un inventaire complet de la diversité de chaque UMAP via le fichier `ore_biodiversity.json`. Ce fichier est **attaché au DID UMAP** et publié sur Nostr.

**Types d'inventaire supportés (capturés par plantnet.html) :**

| Type | Icône | Poids | Description |
|------|-------|-------|-------------|
| `plant` | 🌱 | 2.0 | Plantes (reconnaissance PlantNet) |
| `insect` | 🐛 | 1.5 | Insectes |
| `animal` | 🦊 | 1.5 | Animaux |
| `object` | 🔧 | 1.0 | Équipements et outils partagés |
| `place` | 🏠 | 1.0 | Lieux d'intérêt |
| `person` | 👤 | 0.5 | Personnes clés |

**Structure du fichier ore_biodiversity.json :**
```json
{
  "species": {...},                    // Legacy: plantes uniquement
  "inventory": {
    "plant": {"items": {...}, "count": 15},
    "insect": {"items": {...}, "count": 3},
    "animal": {"items": {...}, "count": 2},
    "object": {"items": {...}, "count": 5},
    "place": {"items": {...}, "count": 1},
    "person": {"items": {...}, "count": 0}
  },
  "diversity_score": 0.78,             // Score global pondéré (0-1)
  "total_observations": 42,
  "observers": {...}
}
```

**Calcul du diversity_score :**
```
items_score        = min(total_weighted_items × 1.5, 50)  # Pondéré par type
type_diversity     = min(types_with_items × 4, 20)        # Bonus variété
observation_score  = min(total_observations × 0.3, 20)
observer_score     = min(observer_count × 2, 10)

diversity_score = min((sum) / 100, 1.0)
```

**Classe Python :** `OREBiodiversityTracker` dans `ore_system.py`
- `add_inventory_observation()` : Ajoute n'importe quel type d'inventaire
- `get_diversity_summary()` : Résumé complet de tous les types
- Migration automatique des anciens fichiers vers la structure étendue

### 4. Publication et Découverte sur Nostr

Les documents et événements ORE sont publiés sur les relais Nostr avec plusieurs event kinds :

*   **Kind 30800** (DID Document UMAP avec diversité) : Document DID complet (NIP-101)
    - Tag `["d", "did"]` pour identification
    - Tag `["g", "{lat},{lon}"]` pour géolocalisation
    - Tag `["t", "inventory"]` pour marquer les données d'inventaire
    - **Tags de diversité (nouveaux) :**
      - `["diversity_score", "0.78"]` - Score global de diversité (0-1)
      - `["biodiversity_score", "0.65"]` - Score legacy (plantes uniquement)
      - `["species_count", "15"]` - Nombre d'espèces
      - `["total_observations", "42"]` - Nombre total d'observations
      - `["inventory_plant", "15"]` - Compteur par type
      - `["inventory_object", "5"]`
      - `["inventory_insect", "3"]`
      - etc.
    - Publication via `_publish_umap_did_with_biodiversity()` dans `ore_system.py`
    - **Mise à jour automatique** à chaque nouvelle observation d'inventaire
    
*   **Kind 30312** (ORE Meeting Space) : Espace géographique persistant pour vérifications
    - Tag `["d", "ore-space-{lat}-{lon}"]` pour identification unique
    - Tag `["g", "{lat},{lon}"]` pour géolocalisation
    - Tag `["room", "UMAP_ORE_{lat}_{lon}"]` pour salle VDO.ninja
    - Publication lors de l'activation du mode ORE
    
*   **Kind 30313** (ORE Verification Meeting) : Réunions de vérification planifiées
    - Tag `["d", "ore-verification-{lat}-{lon}-{timestamp}"]`
    - Tag `["a", "30312:{authority}:ore-space-{lat}-{lon}"]` pour référencer la salle
    - Tag `["start", "{unix_timestamp}"]` pour la date de vérification
    - Publication automatique lors de création de réunions de vérification

### 5. Inventaire Participatif (plantnet.html)

Le système ORE est alimenté par les observations des citoyens via l'interface `UPlanet/earth/plantnet.html` :

**Workflow d'observation :**
```
1. Utilisateur photographie un élément (plante, objet, lieu...)
   ↓
2. Publication NOSTR (kind 1, tags: #BRO #inventory #[type])
   ↓
3. Bot IA détecte et identifie l'élément (PlantNet ou IA générique)
   ↓
4. Génération du contrat de maintenance :
   - Kind 1 (réponse simple, sans markdown)
   - Kind 30023 (blog avec image et détails en markdown)
   - Kind 30312 (ORE Meeting Space)
   ↓
5. OREBiodiversityTracker.add_inventory_observation()
   └─→ ore_biodiversity.json mis à jour
   ↓
6. DID UMAP (kind 30800) republié avec diversity_score à jour
```

**Règle des 28 jours :**
- Si une observation/contrat n'a pas reçu de **like** dans les 28 jours :
  - L'observation et ses événements associés sont **supprimés**
  - Cela évite l'accumulation de données non validées par la communauté
- Implémenté dans `NOSTR.UMAP.refresh.sh` via `cleanup_inventory_without_likes()`

### 6. Vérification et Récompense Économique

C'est le point crucial qui connecte l'action écologique à la valeur économique.

*   **Vérification** : La conformité au contrat ORE est vérifiée (par satellite, IoT, ou vérification humaine via des sessions VDO.ninja).
*   **Déclenchement de la récompense** : Une fois la conformité validée, l'opérateur du système (le "Capitaine") utilise le script `UPLANET.official.sh`.
*   **Flux de la récompense** : Le script exécute un virement en Ẑen depuis le portefeuille des réserves coopératives (`UPLANETNAME_ASSETS`) vers le portefeuille de l'UMAP.

**Important** : Le système ORE ne crée pas de nouvelle monnaie. Il **redistribue** des Ẑen déjà existants, accumulés dans les réserves de la coopérative, assurant ainsi une économie circulaire et stable.

## Utilisation par un Client Nostr

Un client Nostr (comme Damus, Amethyst, ou une application web dédiée) peut interagir avec le système ORE de manière simple et décentralisée.

### 1. Découvrir les UMAP avec Contrats ORE

Pour trouver les parcelles engagées :

1.  **S'abonner aux DIDs** : Le client s'abonne aux événements de `kind: 30800` sur les relais Nostr (NIP-101).
2.  **Filtrer les UMAP** : Il suffit de parcourir les événements reçus et de filtrer ceux dont le champ `"type"` est `"UMAPGeographicCell"`.
3.  **Identifier les contrats actifs** : Le client analyse le champ `"environmentalObligations"` pour trouver les UMAP avec un contrat ORE actif.

### 2. Consulter un Contrat ORE

Une fois une UMAP intéressante identifiée, le client peut :

1.  **Afficher les détails** : Présenter les informations du document DID de manière lisible : coordonnées GPS, description du contrat, montant de la récompense.
2.  **Vérifier le fournisseur** : Le champ `provider` dans le contrat ORE est un DID. Le client peut résoudre ce DID pour vérifier l'identité de l'entité qui valide le contrat.
3.  **Suivre les mises à jour** : En "suivant" la clé publique Nostr de l'UMAP, le client reçoit automatiquement toutes les mises à jour de son statut ORE (ex: `verificationStatus` qui passe de `pending` à `verified`).

### 3. Participer à la Vérification (futur)

Grâce à l'intégration de points de service comme VDO.ninja dans le document DID, un client pourrait permettre à ses utilisateurs de rejoindre des sessions de vérification en direct, renforçant ainsi la dimension participative du système.

## Comparaison Économique : ORE Décentralisé vs ORE Notarié

Le système ORE de UPlanet représente une révolution économique dans la mise en place des Obligations Réelles Environnementales, en éliminant les coûts prohibitifs du système traditionnel.

### Coûts des ORE Traditionnels (via Notaire)

Le système d'ORE classique, tel qu'utilisé en France depuis 2016, implique des coûts considérables :

*   **Frais notariaux** : Entre 2 000 € et 5 000 € par contrat pour la rédaction et l'enregistrement
*   **Frais d'expertise environnementale** : 3 000 € à 10 000 € pour l'évaluation initiale de la parcelle
*   **Inscription au service de publicité foncière** : 500 € à 1 000 €
*   **Frais de suivi annuel** : 1 000 € à 3 000 € par an pour la vérification de conformité
*   **Coûts administratifs** : Délais de 6 à 12 mois pour la mise en place

**Total estimé pour un contrat ORE traditionnel** : **Entre 6 500 € et 19 000 € la première année**, puis 1 000 € à 3 000 € par an.

Ces coûts sont tellement élevés qu'ils rendent les ORE inaccessibles pour la plupart des petits propriétaires et limitent considérablement leur déploiement à grande échelle.

### Coûts du Système ORE Décentralisé UPlanet

Le système UPlanet réduit ces coûts à presque **zéro** grâce à :

*   **Création de contrat** : Gratuite (publication d'un événement Nostr)
*   **Enregistrement** : Gratuit (stockage décentralisé sur réseau Nostr)
*   **Vérification** : Coût marginal (observation satellite open data, vérification communautaire)
*   **Mise à jour du statut** : Gratuite (mise à jour du document DID)
*   **Récompense** : Automatisée (transaction en Ẑen, frais négligeables)
*   **Délai de mise en place** : Quelques minutes

**Total estimé pour un contrat ORE UPlanet** : **< 1 € en coûts techniques**, instantané.

### Impact sur la Scalabilité

Cette différence de coût n'est pas anodine. Elle change radicalement l'équation économique de la protection environnementale :

| Critère | ORE Notarié | ORE UPlanet | Ratio |
|---------|-------------|-------------|-------|
| Coût initial | 6 500 - 19 000 € | < 1 € | **÷ 6 500 minimum** |
| Coût annuel | 1 000 - 3 000 € | ~ 0 € | **÷ infini** |
| Délai de mise en place | 6-12 mois | 5 minutes | **÷ 50 000** |
| Accessibilité | Grandes propriétés uniquement | Toute parcelle, partout | **Universel** |
| Transparence | Opaque (registres privés) | Totale (réseau public) | **100%** |

### Démocratisation de la Protection Environnementale

Avec des coûts divisés par plusieurs milliers, le système UPlanet permet :

*   **Multiplication massive** : Passer de quelques centaines de contrats ORE en France à des millions de contrats mondiaux
*   **Inclusion des petits acteurs** : Un jardin partagé, une parcelle forestière familiale, un toit végétalisé peuvent tous bénéficier d'un contrat ORE
*   **Rapidité de déploiement** : Réagir en temps réel aux urgences écologiques
*   **Économie circulaire** : Les récompenses en Ẑen créent une incitation économique directe, sans intermédiation coûteuse

### Références

*   Campagnes de financement pour ORE traditionnels : [Réserves de Biodiversité 2025 - Ulule](https://fr.ulule.com/reserves-de-biodiversite-2025/)
*   Code de l'environnement français (Art. L132-3) : Obligations Réelles Environnementales

---

## Conclusion

Le système ORE de UPlanet ne se contente pas de reproduire le mécanisme des ORE traditionnels : il le rend **économiquement viable à l'échelle planétaire**. En supprimant les coûts notariaux et administratifs grâce à la décentralisation, il transforme la protection de l'environnement d'un luxe réservé aux grandes structures en un outil accessible à tous.

C'est cette accessibilité qui permettra au "cadastre écologique" de devenir une réalité mondiale, où chaque parcelle de terre peut devenir un acteur rémunéré de la régénération écologique.

---

## 🔗 Liens Utiles

- **Interface PlantNet** : `UPlanet/earth/plantnet.html`
- **Commons Editor** : `UPlanet/earth/collaborative-editor.html`
- **Système PlantNet** : `Astroport.ONE/docs/PLANTNET_SYSTEM.md`
- **Documents Collaboratifs** : `Astroport.ONE/docs/COLLABORATIVE_COMMONS_SYSTEM.md`
- **Journaux N²** : `Astroport.ONE/docs/JOURNAUX_N2_NOSTRCARD.md`
- **Script UMAP** : `Astroport.ONE/RUNTIME/NOSTR.UMAP.refresh.sh`
- **Tracker Python** : `Astroport.ONE/tools/ore_system.py`

---
