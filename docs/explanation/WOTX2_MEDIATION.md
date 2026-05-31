# WoTx² — Assurance Mutualiste & Médiation décentralisée

**Version** : 1.0 — Mai 2026  
**Statut** : Production  
**License** : AGPL-3.0

---

## Pourquoi remplacer l'assurance centralisée ?

L'assurance conventionnelle repose sur un intermédiaire opaque : une société qui collecte des primes, évalue les sinistres et décide de l'indemnisation. Ce modèle présente trois problèmes fondamentaux pour une coopérative pair-à-pair :

1. **Confiance déléguée à un tiers** — l'assureur est juge et partie
2. **Opacité des critères** — les conditions d'exclusion sont rédigées pour minimiser les paiements
3. **Extraction de valeur** — une fraction significative des primes part en frais de gestion et bénéfices

WoTx² propose une alternative : l'**assurance mutualiste fondée sur la Toile de Confiance**. Le cercle de pairs qui vous connaît directement (N1) devient le premier arbitre. Le cercle élargi (N2, amis des amis) devient le tribunal de second recours. Il n'y a plus d'assureur — seulement une communauté qui se co-garantit.

---

## Les deux cercles de médiation

### Cercle N1 — Médiation amiable (~100 pairs)

Le cercle N1 est défini par le **Kind 3** (liste de contacts NOSTR) de chacune des deux parties. Les contacts *communs* aux deux parties constituent naturellement les médiateurs les mieux placés : ils connaissent les deux protagonistes, comprennent le contexte local, ont intérêt à une résolution harmonieuse.

La médiation N1 est informelle et rapide. Elle vise la conciliation, pas la sanction.

**Seuil d'activation** : ≤ 10 ẐEN ou tout désaccord déclaré.

### Cercle N2 — Arbitrage formel (~10 000 pairs)

Le cercle N2 est construit à partir de `amisOfAmis.txt` — la liste agrégée des contacts de contacts. Cinq membres titrés (détenteurs d'un PERMIT WoTx² niveau X2 minimum) sont sélectionnés pour former un panel d'arbitrage.

L'arbitrage N2 est structuré, avec un délai de 7 jours et un verdict exécutoire.

**Seuil d'activation** : > 10 ẐEN ou échec de la médiation N1.

---

## Le pool de solidarité

Le pool de solidarité n'est pas une prime d'assurance. C'est la **fraction TRÉSORERIE** du PAF (Participation aux Frais), allouée selon la règle 3×1/3 définie dans `ZEN.ECONOMY.sh` :

```
PAF versé par chaque MULTIPASS
  ├── 1/3 → R&D (développement du commun)
  ├── 1/3 → ASSETS (investissement local)
  └── 1/3 → TRÉSORERIE (pool de solidarité)
```

Les réparations sont prélevées sur la TRÉSORERIE de la station hôte et créditées via Kind 7 (`+N` ẐEN) sur le wallet du plaignant. La trace est immutable dans Kind 1506 (journal d'actes).

---

## Le rôle des objets à `skill_required`

Un Kind 30505 (objet partagé) peut porter le tag :
```
["skill_required", "permis-conduire-vehicule:x2"]
```

Ce tag crée une **présomption de faute** en cas de friction : si le défendeur ne détient pas le niveau WoT requis pour l'objet qu'il a utilisé, la médiation penche structurellement en faveur du plaignant.

En médiation N1, ce tag est **indicatif** (critère de pondération des votes).  
En arbitrage N2, ce tag est **contraignant** (présomption légale de faute).

Cette mécanique crée une incitation positive à progresser dans la WoT : valider ses compétences n'est pas une formalité bureaucratique mais une protection réelle pour soi et pour les communs.

---

## Le scénario du permis de conduire WoT

Le cas d'usage canonique illustre la cohérence du système :

**Contexte** : jean possède une voiture partagée taggée `skill_required: permis-conduire-vehicule:x2`. Il a lui-même un niveau x1 (auto-proclamé). coucou utilise la voiture et provoque un accrochage.

**Avant WoTx²** : litige civile classique, longue procédure, résultat imprévisible.

**Avec WoTx²** :
1. coucou publie un Kind 1984 friction déclarant l'incident
2. Le relay 1984.sh détecte et crée un dossier Kind 30506
3. Les 5 contacts communs à jean et coucou reçoivent une notification
4. Ils votent via Kind 1506 (vote_amiable) : +1 pour indemnisation, -1 contre
5. Si majorité positive (≤ 10 ẐEN) : résolution directe, Kind 7 transfert
6. Si > 10 ẐEN : panel N2 avec 5 membres titrés, délai 7 jours

La `skill_required: x2` sur la voiture implique que même jean (propriétaire) devrait attendre d'avoir 12 attestations WoT pour conduire légitimement. L'arbitrage en tient compte.

**Résultat attendu** : 5 ẐEN de dédommagement + incitation mutuelle à valider les compétences.

---

## L'émergence de la gouvernance

Le système de médiation WoTx² ne crée pas de règles arbitraires — il révèle les règles que la communauté applique déjà implicitement, en les rendant visibles et exécutables.

Chaque vote Kind 1506 est un acte de gouvernance distribuée. La jurisprudence émerge de l'accumulation de ces actes. Les patterns de médiation N1 répétés peuvent alimenter des Kind 30500 (recettes de résolution) qui documalisent les pratiques acceptées.

C'est la **gouvernance par les communs** : les règles naissent de l'usage, pas de l'autorité.

---

## Références

- **[reference/KIND_30506_JUSTICE.md](../reference/KIND_30506_JUSTICE.md)** — Spec technique complète
- **[reference/WOTX2_SYSTEM.md](../reference/WOTX2_SYSTEM.md)** — Architecture WoTx²
- **[how-to/REPORT_FRICTION.md](../how-to/REPORT_FRICTION.md)** — Guide pratique
- **[tutorials/WOTX2_DEMO_SCENARIO.md](../tutorials/WOTX2_DEMO_SCENARIO.md)** — Scénario de démo
- `ZEN.ECONOMY.sh` — Règle 3×1/3 et pool TRÉSORERIE
- `nostr-nips/56-friction-mediation-extension.md` — Extension NIP-56
- `explanation/minelife_wikipedia_wot.md` — Philosophie WoT (contexte général)
