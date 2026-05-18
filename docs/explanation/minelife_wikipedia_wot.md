# MineLife — Un Wikipédia décentralisé assemblé par la Toile de Confiance

> Ce document explique **pourquoi** MineLife fonctionne comme il fonctionne.
> Pour utiliser l'interface, voir [how-to/MINELIFE.md](../how-to/MINELIFE.md).
> Pour les schemas NOSTR, voir [reference/NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md).

---

## La vérité n'est pas absolue, elle est relative à ta constellation

Un Wikipédia classique repose sur une seule source de vérité : la communauté qui édite le serveur central. Si cette communauté se trompe, si elle est corrompue, ou si ton accès est censuré, ta connaissance est faussée.

MineLife fonctionne autrement. La "vérité" sur une compétence — qui la détient, à quel niveau, avec quelle ressource associée — **dépend du voisinage NOSTR que tu vois depuis ta station**. Deux stations dans des constellations différentes peuvent avoir des états du savoir légèrement différents. Ce n'est pas un bug : c'est la conséquence directe du relativisme décentralisé.

Ce que tu vois dans MineLife, c'est la somme des certifications (Kind 30503), des recettes (Kind 30500) et des ressources (Kind 30504) que ton relay local a synchronisés. Ton relay local synchronise avec ses pairs via `backfill_constellation.sh`. Ton voisinage intellectuel est donc aussi ton voisinage réseau.

---

## Le Capitaine comme bibliothécaire souverain

Dans un Astroport classique, le Capitaine héberge des utilisateurs (MULTIPASS) et opère les services de base. Avec le profil `ai-company` + `nextcloud`, il devient quelque chose de plus : un **bibliothécaire souverain**.

En déposant ses propres fichiers `.md` et `.pdf` dans son Nextcloud (`~/nextcloud/Astroport/<skill>/`), le Capitaine **colore sémantiquement** sa station. Quand un utilisateur de sa station demande `#rec linux` à BRO, l'IA répond en priorité avec les ressources que le Capitaine a choisies, indexées localement dans Qdrant, sans passer par un serveur tiers.

Ce n'est pas une bibliothèque passive. Le Capitaine décide :
- **Quoi** indexer (quels savoirs, quels niveaux, quelle langue)
- **Comment** l'organiser (par skill, par projet, par contexte local)
- **Pour qui** (sa communauté territoriale, son UMAP)

Deux Capitaines en Bretagne et en Occitanie indexeront des ressources différentes, dans des langues et des contextes différents, sans coordination centrale. C'est **la diversité culturelle encodée dans l'architecture**.

---

## La formation comme acte politique : contribuer c'est exister

Dans MineLife, publier un Kind 30504 (ressource de formation) est un acte de contribution au commun. La ressource est :

- **Stockée sur IPFS** — adressée par contenu, censure-résistante
- **Signée par ton identité NOSTR** — attribution permanente, inaliénable
- **Indexée dans Qdrant** — interrogeable sémantiquement, sans index central
- **Propagée via N²** — visible par toute la constellation

Ton CID IPFS et ta pubkey NOSTR voyagent ensemble dans le payload Qdrant. Même si demain tu perds ton accès à la station, ta contribution reste attributée à toi dans l'index distribué.

---

## L'effet constellation : mutualisation sans fusion

ChatGPT a une mémoire unique, centrale, monolithique. Tous les utilisateurs contribuent au même modèle, contrôlé par une entité privée.

La constellation Astroport a une mémoire distribuée, fédérée, composite. Chaque station a son Qdrant local, indexé par son Capitaine. Les ressources Kind 30504 se propagent entre stations via backfill N². Chaque station peut choisir de re-indexer les ressources reçues de ses pairs.

Le résultat : une **intelligence collective qui grandit sans se centraliser**. Plus il y a de Capitaines-bibliothécaires, plus le savoir est riche et diversifié — mais il n'existe pas de "cerveau central" qui pourrait être corrompu, censuré ou racheté.

---

## Le Crafting comme validation par le pair

La certification dans MineLife n'est pas délivrée par une autorité mais **calculée par le pair**. Le processus de "crafting" d'une compétence composite (Kind 30503) exige que les ingrédients (Kind 30503 prérequis) soient déjà certifiés. La grille WYSIWYG de MineLife est le miroir UI de ce calcul.

Trois réactions positives de pairs compétents (Règle A) ou un adoubement direct d'un pair de niveau supérieur (Règle B) suffisent. Il n'y a pas de jury, pas de commission, pas de frais. La confiance est distribuée dans le réseau, pas déléguée à une instance.

Cette mécanique est **homomorphe à git** : comme git permet à chaque clone d'avoir une histoire complète sans dépendre d'un serveur, WoTx2 permet à chaque station d'avoir un état de certification complet sans dépendre d'un Oracle.

---

## Extensibilité : tous les savoirs, toutes les cultures

Le protocole ne connaît que des tags `t`. Tout tag non réservé est un skill valide : `menuiserie`, `médiation`, `ore-verifier`, `phytothérapie`, `musique-jazz`. Chaque communauté peut créer ses permits, ses recettes, ses ressources — sans permission de quiconque.

Une coopérative de menuisiers en Corrèze et un collectif de musiciens à Marseille utilisent le même protocole, le même relay NOSTR, le même format Kind 30504 — mais leurs bases de connaissance Qdrant seront orthogonales. Ils ne s'interfèrent pas, mais ils peuvent s'enrichir mutuellement si leurs constellations se rejoignent.

---

## Voir aussi

- [how-to/MINELIFE.md](../how-to/MINELIFE.md) — utiliser l'interface
- [how-to/KNOWLEDGE_EMBEDDINGS.md](../how-to/KNOWLEDGE_EMBEDDINGS.md) — indexer ses documents
- [tutorials/setup_learning_hub.md](../tutorials/setup_learning_hub.md) — configurer sa station comme hub d'apprentissage
- [reference/NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md) — spec Kind 30504
- [explanation/ORACLE_SYSTEM.md](ORACLE_SYSTEM.md) — le rôle de l'Oracle dans la certification
