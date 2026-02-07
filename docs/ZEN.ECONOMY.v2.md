# Modèle Économique G1FabLab — Règle des 3 Tiers (v2)

**Version enrichie et optimisée.** Ce document décrit ce que nous sommes, nos règles de redistribution et les références techniques. Aucun tiers n’est partie aux engagements contractuels du collectif ; le collectif signe et paie en son nom propre.

---

## Partie I — Ce que nous sommes

### Une AMAP Numérique Citoyenne

Le **G1FabLab** est une **AMAP Numérique Citoyenne** : un collectif de citoyens qui mutualise des infrastructures numériques (serveurs, stockage, réseau) pour faire tourner des services communs. Les personnes qui hébergent le matériel sont défrayées par le collectif ; celles qui utilisent les services contribuent par une redevance d’usage. Il n’y a ni investisseur ni dividende : il y a des **Parrains**, **Armateurs** et **Co-Bâtisseurs** qui mettent des ressources à disposition et perçoivent une **redevance d’hébergement** ou une **indemnité**, dans le cadre d’une **Charte de Redistribution Budgétaire** (règle des 3 tiers).

- **Analogie** : comme une AMAP relie producteurs et consommateurs autour d’un panier, nous relions ceux qui fournissent l’infrastructure (Armateurs), ceux qui l’opèrent (Capitaines), et ceux qui en bénéficient (Usagers, Parrains), autour d’un « panier » de services numériques et d’une clé de répartition fixe.
- **Engagement contractuel et paiement** : le collectif **G1FabLab** est seul responsable de ses engagements. Il signe en son nom propre et **le règlement des contributions aux coûts (frais d’occupation et charges) est à la charge de G1FabLab**. Aucun tiers n’est partie au contrat ni responsable du paiement direct envers les bailleurs ou prestataires.

### Transparence budgétaire

Ce document définit la **politique de transparence budgétaire** et de **redistribution des ressources** au sein du collectif G1FabLab. L’objectif est la pérennité des infrastructures numériques (Cloud Libre) et physiques (Stations Astroport) via un modèle équitable : le **3×1/3**.

### Les trois types de jetons (usage interne)

1. **Jetons d’Usage** → **MULTIPASS** : accès et transactions quotidiennes
2. **Jetons de Contribution** → **ZEN Card** : mise à disposition de ressources (matériel, temps)
3. **Jetons de Gouvernance** → **UPassport** : participation aux décisions collectives

Le ẐEN n’est pas une monnaie financière convertible ; c’est un **jeton utilitaire interne** (unité de compte, droits d’usage, clé de répartition pour les facturations du collectif).

---

## Partie II — Charte de Redistribution Budgétaire (Règles du Jeu)

### Rôles (analogie atelier partagé)

| Rôle | Rôle technique | Rémunération / contrepartie |
|------|----------------|-----------------------------|
| **Armateur** | Fournisseur de ressources (matériel, hébergement) | Redevance d’hébergement / indemnité (1/3) |
| **Capitaine** | Opérateur technique (maintenance, exploitation) | Rétribution de prestation (1/3) |
| **Usagers** | Utilisation des services | Redevance d’usage (HT + TVA) |
| **Parrains** | Contributeurs d’infrastructure (équipement collectif) | Crédit d’usage, droits étendus, pas de redevance hebdo pendant la période souscrite |

Chaque redevance sert à défrayer l’opérateur et le fournisseur de matériel ; l’excédent permet au collectif d’acquérir des ressources durables.

### Philosophie

Le G1FabLab **ne génère pas de profits spéculatifs**. Il collecte des contributions (dons, redevances de service) et les répartit selon une clé fixe : ceux qui travaillent et ceux qui mettent du matériel à disposition sont défrayés (indemnités et redevances d’hébergement, pas de dividendes).

### La règle des 3 tiers et la 3xPAF

Sur chaque Astroport, la **règle des 3xPAF** répartit le versement des ẐEN d’usage entre l’Armateur et le Capitaine : **1× PAF** → NODE (Armateur), **2× PAF** → MULTIPASS Capitaine (soit 3× PAF au total par station et par semaine, ex. 14 + 28 = 42 Ẑen).

Pour chaque service facturé ou contribution reçue au niveau collectif, le montant est en outre divisé en **trois parts égales** (allocation 3×1/3) :

| Tiers | Bénéficiaire | Objet |
|-------|--------------|--------|
| **1/3** | Réserve de fonctionnement (Projet) | Trésorerie : charges, assurance, secours, remplacement matériel. Géré sur le compte du projet (`UPLANETNAME_CASH`). |
| **1/3** | Capitaines | Rétribution du travail (maintenance, astreinte, développement). Facturation au collectif. |
| **1/3** | Armateurs | Redevance d’hébergement / indemnité d’occupation ou loyer de matériel. Réglée via le système de crédits internes (ex. 1/3 de la valorisation du service). |

**Exemple Armateur** : mise à disposition d’un serveur (ex. 500€) → redevance d’hébergement issue de l’activité de ce serveur (portefeuille collectif `UPLANETNAME_ASSETS` et flux NODE).

### Modèle de fonctionnement (résumé)

- **Coûts opérationnels** : payés par la **Trésorerie Coopérative** (`UPLANETNAME_CASH`). Ex. 3× PAF = 42 Ẑen/semaine (1× PAF → NODE Armateur, 2× PAF → MULTIPASS Capitaine).
- **Collecte des redevances** : portefeuille d’exploitation **CAPTAIN_DEDICATED** (loyers HT usagers) ; TVA (20 %) → `UPLANETNAME_IMPOT`.
- **Allocation 3×1/3** : depuis CAPTAIN_DEDICATED (surplus brut) → provision IS (15–25 %) → surplus net réparti en 33,33 % CASH, 33,33 % RnD, 33,34 % ASSETS. Déclenchement hebdomadaire (anniversaire Capitaine) si solde CAPTAIN_DEDICATED > 0.

**Règlement des contributions aux coûts (frais d’occupation et charges)** : **à la charge du collectif G1FabLab**. Le collectif règle les indemnités et redevances d’hébergement ainsi que les prestations dues aux Armateurs et Capitaines. Les modalités de paiement (ex. virement SEPA) sont effectuées par le collectif en son nom propre ; aucun tiers n’est responsable du paiement direct envers le bailleur ou le prestataire.

---

## Partie III — Référence technique (compta interne)

### Portefeuilles (conformité code)

| Nom logique | Fichier dunikey | Rôle |
|-------------|------------------|------|
| **UPLANETNAME_CASH** | `uplanet.CASH.dunikey` | Trésorerie (1/3) |
| **UPLANETNAME_RND** | `uplanet.RnD.dunikey` | R&D (1/3) |
| **UPLANETNAME_ASSETS** | `uplanet.ASSETS.dunikey` | Actifs (1/3) |
| **UPLANETNAME_IMPOT** | `uplanet.IMPOT.dunikey` | Provisions fiscales (TVA, IS) |
| **CAPTAIN_DEDICATED** | `uplanet.captain.dunikey` | Collecte redevances (source 3×1/3) |
| **NODE** | `secret.NODE.dunikey` | Portefeuille Armateur (redevance hébergement) |

### Scripts principaux

| Script | Fonction | Fréquence |
|--------|----------|-----------|
| `UPLANET.init.sh` | Initialisation portefeuilles (NODE, CAPTAIN, Collectifs) | Une fois |
| `ZEN.ECONOMY.sh` | PAF + dégradation progressive + Burn 4 semaines | Hebdomadaire |
| `ZEN.COOPERATIVE.3x1-3.sh` | Provision IS + allocation 3×1/3 depuis CAPTAIN_DEDICATED | Hebdomadaire (anniversaire Capitaine) |
| `NOSTRCARD.refresh.sh` | Collecte redevances MULTIPASS (1Ẑ HT + 0,2Ẑ TVA) | Hebdomadaire |
| `PLAYER.refresh.sh` | Collecte redevances ZEN Cards (4Ẑ HT + 0,8Ẑ TVA) | Hebdomadaire |
| `uplanet_onboarding.sh` / `captain.sh` | Embarquement et dashboard | À la demande |

### Flux hebdomadaire (schéma)

```
1. COLLECTE REDEVANCES  →  CAPTAIN_DEDICATED (HT)  +  UPLANETNAME_IMPOT (TVA)
2. PAIEMENT PAF          →  CASH → NODE (Armateur) + CAPTAIN MULTIPASS (salaire)
3. ALLOCATION 3×1/3      →  CAPTAIN_DEDICATED (surplus) → IS → CASH / RnD / ASSETS
```

### Service de remboursement (conversion ẐEN → euros)

* Constat d'activité : Le protocole mesure l'activité (Maintenance, Hébergement) et crédite le compte interne en ẐEN.

* Facturation : Lorsque le solde interne le permet, le membre (Armateur/Capitaine) émet une facture en Euros adressée au G1FabLab.

    Libellé : "Prestation d'hébergement serveur" ou "Maintenance technique".

* Paiement : Le G1FabLab valide la facture (si cohérente avec l'activité mesurée) et déclenche le virement bancaire via son compte fiscal.

* Équilibrage : Les crédits ẐEN correspondants sont brûlés ou archivés pour solder le compte interne.

---

## Partie IV — Guide contributeur (condensé)

### Rôles et contreparties

- **MULTIPASS** : redevance 1 Ẑ/semaine (+ TVA) → 10 Go uDRIVE, identité souveraine, économie circulaire (ex. 1 Like = 1 Ẑ).
- **Parrain** : contribution annuelle (ex. 50 Ẑ crédit service) → 128 Go NextCloud, voix consultative, exonération redevance hebdo (1 an).
- **Capitaine** : rétribution de base (ex. 28 Ẑ/semaine) + excédent de son essaim ; facturation au collectif (prestation).
- **Armateur** : redevance d’hébergement / loyer de matériel (1/3) ; déclaration en BIC (location) ou BNC (prestation).

### Fiscalité recommandée

- **Principe** : on déclare les **euros reçus** (après conversion via le service de remboursement du collectif), pas les Ẑen. Le fait générateur de l’impôt est le remboursement en euros.
- **Statut adapté** : Micro-Entrepreneur en **BNC** pour la plupart des membres (Armateurs, Capitaines, créateurs de contenu). Activités = prestations de services (mise à disposition matériel, maintenance, création de contenu).
- **Armateur** : revenus de location / mise à disposition (BIC ou BNC) ; justificatifs = loyer, redevance d’hébergement. Évite toute requalification en « vendeur de titres » ou « banque ».

### Pourquoi ce vocabulaire protège tout le monde

- **Armateur** : pas de dividende ni de capital ; indemnité ou loyer → déclaration simple (BIC/BNC). Pas de plus-value sur actifs numériques.
- **Collectif** : engagements et paiements au nom de **G1FabLab** uniquement ; responsabilité juridique claire ; aucun tiers n’est solidaire des engagements contractuels.

---

## Dictionnaire de remplacement (sémantique conforme)

À utiliser systématiquement : présenter le projet comme une **AMAP Numérique Citoyenne** / **Coopérative d’infrastructure numérique**, jamais comme une structure d’investissement.

| À éviter (financier) | À utiliser (service / commun) |
|----------------------|------------------------------|
| Investisseur / Actionnaire | Parrain / Armateur / Co-Bâtisseur |
| Dividende / Rente | Redevance d’hébergement / Indemnité |
| Capital (social) | Patrimoine commun / Infrastructure |
| Achat de token | Crédit d’usage / Droit d’accès |
| ROI | Économie circulaire / Compensation |
| Cours du ẐEN | Valeur d’échange interne |
| Bénéfice / Profit | Excédent de gestion / de fonctionnement |
| Parts sociales | Crédits service / Droits d’usage |
| Sociétaire | Parrain / Contributeur |

---

## Liens utiles

- **Système ORE** : `Astroport.ONE/docs/ORE_SYSTEM.md`
- **Documents collaboratifs** : `Astroport.ONE/docs/COLLABORATIVE_COMMONS_SYSTEM.md`
- **Système PlantNet** : `Astroport.ONE/docs/PLANTNET_SYSTEM.md`
- **Système WoTx2** : `Astroport.ONE/docs/WOTX2_SYSTEM.md`
- **Politique d’intrusion** : `Astroport.ONE/docs/ZEN.INTRUSION.POLICY.md`
- **Oracle** : `Astroport.ONE/docs/ORACLE_SYSTEM.md`

---

Voici les documents juridiques prêts à l'emploi et le guide opérationnel pour orchestrer les interactions sur vos pages Open Collective.

Ces contrats sont rédigés pour être conformes aux exigences d'Open Collective Europe (OCE) : ils formalisent des relations de **prestation de service** et de **location d'infrastructure**, éliminant tout vocabulaire spéculatif.

---

### 1. CONTRATS TYPES (À copier-coller et signer)

#### DOCUMENT A : Pour l'Armateur (Hébergeur de Nœud)
*À utiliser par toute personne (particulier ou pro) qui héberge une machine du réseau chez elle.*

**CONTRAT D'HÉBERGEMENT ET DE MISE À DISPOSITION D'INFRASTRUCTURE**

**ENTRE LES SOUSSIGNÉS :**

1.  **Le Collectif G1FabLab**, représenté par son administrateur, ci-après dénommé **"Le Client"**.
2.  **M./Mme/Société [NOM PRÉNOM OU RAISON SOCIALE]**, demeurant au [ADRESSE COMPLÈTE], ci-après dénommé **"L'Hébergeur"**.

**IL A ÉTÉ CONVENU CE QUI SUIT :**

**Article 1 : Objet du contrat**
L'Hébergeur s'engage à mettre à disposition du Client un espace physique, une alimentation électrique et une connexion réseau pour permettre le fonctionnement continu d'équipements informatiques (serveurs, nœuds de stockage, hubs) nécessaires aux activités numériques du Client.

**Article 2 : Obligations de l'Hébergeur**
L'Hébergeur s'engage à fournir :
*   Un emplacement sécurisé, sec et tempéré pour le matériel.
*   Une alimentation électrique 24h/24 et 7j/7.
*   Une connexion Internet (Fibre ou Haut Débit) stable.
*   Un accès physique de premier niveau (redémarrage) en cas d'incident mineur.

**Article 3 : Propriété du matériel**
Le matériel installé reste la propriété exclusive, inaliénable et insaisissable du Collectif G1FabLab (ou est mis à sa disposition par le biais de parrainages). L'Hébergeur s'interdit de vendre, louer ou céder ce matériel à un tiers.

**Article 4 : Conditions Financières**
En contrepartie de cette prestation d'hébergement et de la consommation des fluides (électricité, bande passante), le Client versera à l'Hébergeur une indemnité mensuelle forfaitaire de **[MONTANT] €**.

**Article 5 : Modalités de Facturation et Règlement**
Le règlement sera effectué mensuellement par virement bancaire, sur présentation d'une facture (si professionnel) ou d'une note de frais (si particulier, dans la limite des frais réels justifiables) déposée sur la plateforme de gestion du Client.

**Article 6 : Durée et Résiliation**
Ce contrat est conclu pour une durée indéterminée. Il peut être résilié par l'une ou l'autre des parties avec un préavis de un mois. En cas de résiliation, l'Hébergeur s'engage à restituer le matériel au Client.

Fait à [VILLE], le [DATE]

**Pour le Client (G1FabLab)** ____________________ **Pour l'Hébergeur** ____________________

---

#### DOCUMENT B : Pour le Capitaine (Prestataire Technique)
*À utiliser par les techniciens (Fred, Yann, etc.) pour facturer leur travail. SIRET obligatoire.*

**CONTRAT DE PRESTATION DE SERVICES NUMÉRIQUES**

**ENTRE LES SOUSSIGNÉS :**

1.  **Le Collectif G1FabLab**, représenté par son administrateur, ci-après dénommé **"Le Client"**.
2.  **[PRÉNOM NOM]**, exerçant sous le statut [AUTO-ENTREPRENEUR / SOCIÉTÉ], SIRET n° [NUMÉRO], demeurant au [ADRESSE], ci-après dénommé **"Le Prestataire"**.

**IL A ÉTÉ CONVENU CE QUI SUIT :**

**Article 1 : Objet**
Le Client confie au Prestataire une mission d'assistance technique, de développement et de maintenance des infrastructures numériques du collectif (réseau UPlanet, serveurs, logiciels).

**Article 2 : Nature des prestations**
Le Prestataire assurera, sans que cette liste ne soit exhaustive :
*   L'installation et la configuration des nœuds serveurs.
*   La maintenance préventive et curative des systèmes (mises à jour, sécurité).
*   Le développement et l'amélioration des outils logiciels Open Source.
*   L'assistance aux utilisateurs du réseau.

**Article 3 : Indépendance**
Le Prestataire exécute sa mission en totale indépendance, sans lien de subordination avec le Client. Il reste libre de l'organisation de son temps et de ses méthodes de travail, sous réserve du respect des objectifs techniques fixés.

**Article 4 : Conditions Financières**
En rémunération de ces prestations, le Prestataire percevra des honoraires fixés à **[MONTANT] €** par [MOIS / HEURE / JOUR].
Le Prestataire déclare être en règle avec ses obligations fiscales et sociales.

**Article 5 : Facturation**
Le Prestataire émettra une facture mensuelle détaillée via la plateforme Open Collective du Client. Le paiement sera effectué par virement bancaire sous 30 jours.

Fait à [VILLE], le [DATE]

**Pour le Client (G1FabLab)** ____________________ **Pour le Prestataire** ____________________

---

### 2. LE PAS À PAS (Guide Opérationnel)

Voici la marche à suivre pour chaque acteur afin d'utiliser vos pages Open Collective.

#### CAS 1 : Je veux financer le réseau (Le "Parrain")
*Je suis un utilisateur ou un soutien qui veut que le réseau existe.*

1.  **Où aller ?** Sur la page du projet dédié à l'infrastructure : **[G1FabLab / Projet CoeurBox](https://opencollective.com/monnaie-libre/projects/coeurbox)**
2.  **Que faire ?** Choisir un palier de contribution ("Parrainage Extension" ou "Mécénat Nœud").
3.  **L'action :** Cliquer sur **"Contribuer"**, régler par Carte Bancaire ou Virement.
4.  **Résultat :** L'argent arrive sur le compte du projet pour acheter le matériel. Je reçois automatiquement un reçu fiscal (si éligible) ou une preuve de don.

#### CAS 2 : Je veux héberger une machine (L'"Armateur")
*J'ai la fibre et de la place chez moi, je veux accueillir un nœud UPlanet.*

1.  **Signature :** Je télécharge, remplis et signe le **"Document A"** (voir ci-dessus) avec un admin du G1FabLab.
2.  **Installation :** Je reçois le matériel (financé par les Parrains) et je le branche.
3.  **Remboursement Mensuel :**
    *   Je vais sur **[G1FabLab / Dépenses](https://opencollective.com/monnaie-libre/expenses/new)**.
    *   Je clique sur **"Soumettre une dépense"** > **"Facture"**.
    *   **Titre :** `Hébergement Nœud UPlanet - [Mois]`
    *   **Montant :** Le montant défini dans mon contrat (ex: 30€).
    *   **Pièce jointe :** Je joins mon Contrat A (la première fois) + ma facture ou note de débit mensuelle.
    *   **Validation :** L'admin valide, je reçois le virement sous quelques jours.

#### CAS 3 : Je travaille sur le réseau (Le "Capitaine")
*Je suis Fred, Yann ou un dev, et je maintiens l'infra.*

1.  **Pré-requis :** J'ai un numéro de SIRET (Auto-entrepreneur).
2.  **Signature :** Je signe le **"Document B"** avec un autre admin du G1FabLab.
3.  **Facturation Mensuelle :**
    *   Je vais sur **[G1FabLab / Dépenses](https://opencollective.com/monnaie-libre/expenses/new)**.
    *   Je clique sur **"Soumettre une dépense"** > **"Facture"**.
    *   **Titre :** `Prestation Maintenance Infrastructure - [Mois]`
    *   **Montant :** Le montant de ma prestation (ex: 400€).
    *   **Pièce jointe :** Ma facture officielle éditée avec mon logiciel de compta (mentionnant mon SIRET et "TVA non applicable" si AE).
    *   **Validation :** Un autre admin approuve.

#### CAS 4 : Le Collectif doit acheter du matériel (L'Admin)
*Il faut commander des Raspberry Pi pour les nouveaux Parrains.*

1.  **Devis :** Je fais un panier sur un site pro (Kubii, Amazon Business, etc.) au nom de : *Open Collective Europe - G1FabLab*.
2.  **Demande :**
    *   Je vais sur le projet **[G1FabLab / Projet CoeurBox](https://opencollective.com/monnaie-libre/projects/coeurbox)**.
    *   Je crée une dépense : **"Payer une facture"**.
    *   Je demande à ce que le **Fournisseur** soit payé directement (en entrant son IBAN) OU je paie avec ma carte perso et je demande un **Remboursement**.
3.  **Justificatif :** Je joins impérativement la facture d'achat détaillée.