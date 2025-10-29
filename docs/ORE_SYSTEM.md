Absolument. Voici une version réécrite du fichier `ORE_SYSTEM.md`, clarifiée, corrigée et axée sur l'implémentation concrète et l'utilisation par un client Nostr.

---

# Le Système ORE de UPlanet : Un Cadastre Écologique Décentralisé

Le système ORE (Obligations Réelles Environnementales) intègre des engagements écologiques vérifiables à des parcelles géographiques (UMAP) en utilisant des identités décentralisées (DID) sur le réseau Nostr. Il crée ainsi un "cadastre écologique" mondial, où la protection de l'environnement devient une activité économiquement valorisée.

## Concepts Clés

*   **UMAP (Universal Map)** : Une cellule géographique de 0.01° x 0.01° (environ 1,2 km²), qui possède sa propre identité numérique.
*   **DID (Identité Décentralisée)** : Chaque UMAP possède un identifiant unique `did:nostr:<clé_publique_hex>`, lui permettant d'avoir un profil, de posséder un portefeuille et de publier des informations sur Nostr.
*   **Contrat ORE** : Un engagement environnemental (ex: "maintenir 80% de couverture forestière") attaché au DID d'une UMAP.
*   **Récompense Ẑen** : La validation du respect d'un contrat ORE déclenche une récompense en Ẑen, la monnaie de l'écosystème UPlanet.

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

### 3. Publication et Découverte sur Nostr

Le document DID est publié sur les relais Nostr en tant qu'événement de **`kind: 30311`** (Événement Remplaçable Paramétré).

*   **Publication** : Le script `did_manager_nostr.sh` est utilisé pour mettre à jour et publier le document DID de l'UMAP.
*   **Découverte** : N'importe quel client Nostr peut s'abonner aux événements de `kind: 30311` pour découvrir les DIDs des UMAP et lire leurs contrats ORE.

### 4. Vérification et Récompense Économique

C'est le point crucial qui connecte l'action écologique à la valeur économique.

*   **Vérification** : La conformité au contrat ORE est vérifiée (par satellite, IoT, ou vérification humaine via des sessions VDO.ninja).
*   **Déclenchement de la récompense** : Une fois la conformité validée, l'opérateur du système (le "Capitaine") utilise le script `UPLANET.official.sh`.
*   **Flux de la récompense** : Le script exécute un virement en Ẑen depuis le portefeuille des réserves coopératives (`UPLANETNAME_ASSETS`) vers le portefeuille de l'UMAP.

**Important** : Le système ORE ne crée pas de nouvelle monnaie. Il **redistribue** des Ẑen déjà existants, accumulés dans les réserves de la coopérative, assurant ainsi une économie circulaire et stable.

## Utilisation par un Client Nostr

Un client Nostr (comme Damus, Amethyst, ou une application web dédiée) peut interagir avec le système ORE de manière simple et décentralisée.

### 1. Découvrir les UMAP avec Contrats ORE

Pour trouver les parcelles engagées :

1.  **S'abonner aux DIDs** : Le client s'abonne aux événements de `kind: 30311` sur les relais Nostr.
2.  **Filtrer les UMAP** : Il suffit de parcourir les événements reçus et de filtrer ceux dont le champ `"type"` est `"UMAPGeographicCell"`.
3.  **Identifier les contrats actifs** : Le client analyse le champ `"environmentalObligations"` pour trouver les UMAP avec un contrat ORE actif.

### 2. Consulter un Contrat ORE

Une fois une UMAP intéressante identifiée, le client peut :

1.  **Afficher les détails** : Présenter les informations du document DID de manière lisible : coordonnées GPS, description du contrat, montant de la récompense.
2.  **Vérifier le fournisseur** : Le champ `provider` dans le contrat ORE est un DID. Le client peut résoudre ce DID pour vérifier l'identité de l'entité qui valide le contrat.
3.  **Suivre les mises à jour** : En "suivant" la clé publique Nostr de l'UMAP, le client reçoit automatiquement toutes les mises à jour de son statut ORE (ex: `verificationStatus` qui passe de `pending` à `verified`).

### 3. Participer à la Vérification (futur)

Grâce à l'intégration de points de service comme VDO.ninja dans le document DID, un client pourrait permettre à ses utilisateurs de rejoindre des sessions de vérification en direct, renforçant ainsi la dimension participative du système.

---