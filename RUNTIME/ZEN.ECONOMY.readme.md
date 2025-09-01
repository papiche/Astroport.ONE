# **L'Écosystème UPlanet ẐEN : De la Vision à la Réalité Coopérative**

## **Partie I : Le Manifeste (Le "Pourquoi")**

### **Deux Mondes, Deux Géométries**

Pour comprendre la différence fondamentale entre l'économie du Ẑen et celle de l'Euro, il ne suffit pas de parler de technologie. Il faut parler de **géométrie**. Chaque système monétaire dessine un "monde" avec ses propres règles, ses propres trajectoires et sa propre expérience vécue.

#### **1. Le Monde de l'Euro : La Sphère de Poincaré**

L'économie de la monnaie-dette, dont l'Euro est un représentant, est un univers dont la géométrie est analogue à celle d'une **sphère**. C'est un monde soumis à la [conjecture de Poincaré](https://fr.wikipedia.org/wiki/Conjecture_de_Poincar%C3%A9).

*   **Ses Propriétés :** Fini, sans bord, non-euclidien. La monnaie est créée par la dette, instaurant une **rareté structurelle**. Les trajectoires que l'on pense parallèles sont en réalité **convergentes**, menant à une compétition inévitable.
*   **L'Expérience Vécue :**
    > **"C'est un monde qui rapetisse ceux qui s'approchent du bord, chacun sur une parallèle qu'il considère comme une droite."**
    Le "bord" est la limite de la solvabilité. En s'en approchant, les possibles de l'acteur se contractent, son énergie est dédiée au service de la dette, non à la création. C'est une **asphyxie économique et cognitive**.

#### **2. Le Monde du Ẑen : Le Plan Coopératif en Expansion**

L'économie du Ẑen est conçue pour avoir une géométrie radicalement différente : celle d'un **plan en expansion, ancré sur un socle coopératif**.

*   **Ses Propriétés :** Ouvert, infini en potentiel, collaboratif. Le Ẑen est créé par l'**apport de valeur réelle** (matériel, compétences) à la coopérative. L'espace est en expansion, rendant le jeu à **somme positive**.
*   **L'Expérience Vécue :**
    > **"C'est un monde qui grandit avec ceux qui construisent, chacun sur un chemin qui enrichit le territoire commun."**
    Le succès d'un membre augmente la valeur et la résilience de l'ensemble. Les possibles s'élargissent en même temps que ceux du collectif. C'est une **synergie économique et cognitive**, dont la physique transparente est inscrite dans le protocole.

Le Ẑen n'est pas une "alternative" à l'Euro. C'est une **invitation à changer de monde** et à choisir une nouvelle géométrie pour nos projets.

---

## **Partie II : La Constitution (Les "Règles du Jeu")**

### **PRÉAMBULE "POUR LES NULS" : L'ANALOGIE DE L'HÔTEL COOPÉRATIF**

Notre écosystème fonctionne comme un **hôtel coopératif** :
*   **L'Armateur** = Le propriétaire de l'immeuble.
*   **Le Capitaine** = Le concierge qui gère l'hôtel.
*   **Les Locataires** = Les clients qui paient pour une chambre.
*   **Les Sociétaires** = Les co-propriétaires de l'hôtel.

Chaque loyer payé par un client sert à payer le concierge et le propriétaire, et le surplus permet à la coopérative d'acheter des forêts et jardins, créant des biens communs durables.

### **MODÈLE ÉCONOMIQUE COOPÉRATIF**

#### **1. Le Coût de Production du Service (La Rémunération des Opérateurs)**
C'est le coût incompressible pour qu'un service fonctionne. Il est fixé à **3x la PAF** (Participation Aux Frais, avec `PAF = 14 Ẑen/semaine`). Il se répartit ainsi :
*   **1x PAF (14 Ẑen) :** Pour l'**Armateur** (coût du matériel et de l'hébergement).
*   **2x PAF (28 Ẑen) :** Pour le **Capitaine** (rémunération de son travail de maintenance).

Cette somme totale (`42 Ẑen/semaine`) est la **Rémunération Totale des Opérateurs**. Elle est prélevée en priorité sur les revenus locatifs collectés par le Capitaine.

#### **2. Le Surplus Coopératif**
C'est ce qui reste APRÈS avoir payé tous les coûts de production. Il appartient au collectif.
**Formule :**
`Surplus = Revenus Locatifs Totaux - (TVA Collectée + Rémunération Totale des Opérateurs)`

Ce surplus est le **bénéfice net de l'essaim**. Il est intégralement reversé à la coopérative.

#### **3. Allocation Coopérative 3x1/3**
Le surplus net de la coopérative (après provision de l'Impôt sur les Sociétés) est alloué selon la règle des **3x1/3** :
*   **1/3 Trésorerie** (`UPLANETNAME.TREASURY`)
*   **1/3 R&D** (`UPLANETNAME.RND`)
*   **1/3 Forêts Jardins** (`UPLANETNAME.ASSETS`)

---

## **Partie III : Le Code de la Route (Le "Comment")**

### **ARCHITECTURE DU SYSTÈME**

| Script | Fonction | Fréquence |
| :--- | :--- | :--- |
| `ZEN.ECONOMY.sh` | Paiement Rémunération Opérateurs | Hebdomadaire |
| `ZEN.COOPERATIVE.3x1-3.sh` | Calcul du Surplus & Allocation | Hebdomadaire |
| `NOSTRCARD.refresh.sh` & `PLAYER.refresh.sh` | Collecte des Loyers & TVA | Hebdomadaire |

### **CONFIGURATION**
Les variables (`PAF`, `TVA_RATE`, etc.) sont définies dans un fichier `.env`. Les portefeuilles (`.IMPOT`, `.TREASURY`, etc.) sont créés automatiquement par le script `UPLANET.official.sh`.

### **LE PONT DE LIQUIDITÉ : CONVERSION ẐEN → EUROS**
C'est un service de rachat offert par la coopérative.
1.  **Demande** via le Terminal.
2.  **Justification** sur IPFS.
3.  **Validation** par le protocole (conformité, trésorerie, règle du 1/3).
4.  **Burn** : Le membre transfère ses Ẑen vers `UPLANETNAME.G1` (destruction).
5.  **Paiement** : Virement SEPA en Euros via l'hôte fiscal.

### **FLUX ÉCONOMIQUES AUTOMATISÉS**

```mermaid
graph TD
    %% Styling definitions
    classDef success fill:#d4edda,stroke:#155724,color:#155724
    classDef error fill:#f8d7da,stroke:#721c24,color:#721c24
    classDef process fill:#d1ecf1,stroke:#0c5460,color:#0c5460
    classDef decision fill:#fff3cd,stroke:#856404,color:#856404
    classDef payment fill:#e8deee,stroke:#4a2d7e,color:#4a2d7e
    classDef allocation fill:#deedf7,stroke:#0b5394,color:#0b5394

    subgraph "Collecte des Loyers"
        A[Locataires paient 1 ou 4 Zen] --> B[MULTIPASS Capitaine]
        B --> C[0.2 ou 0.8 Zen vers U.IMPOT]
    end

    subgraph "Rémunération & Surplus"
        C --> D{Solde Capitaine > 3xPAF ?}
        D -- "Oui" --> E[Paiement 1xPAF à l'Armateur]
        E --> F[Paiement 2xPAF à soi-même]
        F --> G[Surplus reversé]
        D -- "Non (Déficit)" --> H[Paiement partiel depuis MULTIPASS]
        H --> I[Le manque est prélevé sur sa ZenCard<br> Compte Courant d'Associé]
        I --> J[Paiement 1xPAF à l'Armateur]
        J --> K[Paiement 2xPAF à soi-même]
    end

    subgraph "Allocation Coopérative"
        G --> L[U.OPE reçoit Surplus]
        L --> M[Provision 25% IS vers U.IMPOT]
        M --> N[Allocation 3x1/3 du Net]
        N --> O[U.TREASURY]
        N --> P[U.RND]
        N --> Q[U.ASSETS]
    end

    %% Apply styling
    class A,B,C,E,F,G,I,J,K,L,M,N,O,P,Q process
    class D decision
```

---

## **Partie IV : Le Guide de l'Entrepreneur (Le "Et Vous ?")**

### **USER STORIES : LES BÉNÉFICES POUR CHAQUE MEMBRE**

#### **🏠 LE LOCATAIRE : Votre Passeport vers la Souveraineté**
> **"Je paie 1 Ẑen/semaine (≈ 4€/mois) et je gagne ma liberté numérique."**
*   **Ce que vous obtenez :** Une identité souveraine, un stockage décentralisé, et la possibilité de gagner des Ẑen en créant du contenu de qualité.
*   **Pourquoi ?** C'est moins cher qu'un abonnement standard, mais vous n'êtes plus le produit. Vous êtes un citoyen du réseau.

#### **👑 LE SOCIÉTAIRE : Devenez Co-propriétaire**
> **"J'investis 50€/an, je deviens co-propriétaire et mes services premium (128Go de Cloud Privé) sont inclus."**
*   **Ce que vous obtenez :** Tous les avantages du Locataire, PLUS 128Go de NextCloud, un statut de co-propriétaire avec droit de vote, et des parts sociales dans une infrastructure réelle.
*   **Pourquoi ?** Vous dégooglez votre vie et vous investissez dans un actif qui a un double impact : numérique et écologique.

#### **👨‍✈️ LE CAPITAINE : Créez de la Valeur, Gagnez votre Vie**
> **"Je transforme mon ordinateur en source de revenus et je participe à la construction d'un monde meilleur."**
*   **Ce que vous obtenez :** Une rémunération de base garantie de **28 Ẑen/semaine (≈ 112€/mois)**, une formation complète et la possibilité de développer votre "essaim" pour augmenter le surplus coopératif.
*   **Pourquoi ?** Vous monétisez votre compétence technique pour un projet qui a du sens, avec une sécurité de revenu et un impact positif.

---

## **Recommandations Fiscales pour les Membres de l'Écosystème UPlanet/CopyLaRadio**

**Philosophie Générale :** Notre système est conçu pour la transparence. Le but n'est pas d'échapper à la fiscalité, mais de la rendre simple, juste et automatisée. Le fait générateur de l'impôt est la **conversion de vos Ẑen en Euros**. Tant que vos Ẑen restent dans l'écosystème, ils sont considérés comme des "jetons utilitaires" internes à la coopérative.

---

# GUIDE pour ENTREPRENEUR

## **Le Statut Recommandé pour Débuter : La Micro-Entreprise (BNC)**

Pour 99% des membres qui génèrent des revenus (Armateurs, Capitaines, Créateurs de contenu), le statut de **Micro-Entrepreneur** en **Bénéfices Non Commerciaux (BNC)** est la solution la plus simple, la moins coûteuse et la plus adaptée.

### **Pourquoi BNC (Bénéfices Non Commerciaux) ?**
Parce que les activités au sein de notre écosystème sont des **prestations de services intellectuelles ou techniques**, pas de l'achat/revente de marchandises. Exemples :
*   Hébergement de données (Armateur)
*   Maintenance informatique (Capitaine)
*   Création de contenu en ligne (Utilisateur gagnant des likes)

### **Guide Pratique : Devenir Micro-Entrepreneur en 15 minutes**

1.  **Création (Gratuite) :**
    *   Rendez-vous sur le site officiel du guichet unique de l'INPI.
    *   Déclarez votre début d'activité en choisissant "Entrepreneur Individuel" puis le régime "Micro-Entrepreneur".
    *   Dans la description de l'activité, soyez simple et précis. Exemples :
        *   Pour un **Armateur** : "Hébergement informatique, prestations de services numériques".
        *   Pour un **Capitaine** : "Maintenance de systèmes informatiques, support technique".
        *   Pour un **Utilisateur** : "Création de contenu en ligne, animation de communauté".

2.  **Gestion (Simplifiée) :**
    *   Vous n'avez pas besoin d'un comptable. Vous devez simplement tenir un **registre des recettes**. Un simple tableur suffit.
    *   **Colonne 1 :** Date de la conversion en €.
    *   **Colonne 2 :** Origine des Ẑen (ex: "PAF Armateur", "Gains Likes", "Rémunération Capitaine").
    *   **Colonne 3 :** Montant en **Euros** reçu sur votre compte bancaire. C'est ce montant qui fait foi.

3.  **Fiscalité (Ultra-Simplifiée avec le Versement Libératoire) :**
    *   Chaque mois ou trimestre, vous déclarez le montant en euros de vos recettes sur le site de l'URSSAF.
    *   En choisissant l'option du **versement libératoire**, vous payez en même temps :
        *   Vos cotisations sociales (~21-22% de vos recettes).
        *   Votre impôt sur le revenu (~2,2% de vos recettes).
    *   **Avantage :** Une fois ce paiement effectué, vous êtes en règle. Pas de surprise en fin d'année. C'est clair, net et prévisible.

---

## **Application par Rôle**

### **1. Pour l'Armateur**
*   **Son Revenu :** Il reçoit la PAF pour couvrir ses frais réels (électricité, internet...).
*   **Le Processus :** Une fois par mois (par exemple), il a accumulé 50 Ẑen de PAF sur son wallet. Il a une facture d'électricité de 50€. Il utilise le "Pont de Liquidité" pour convertir 50 Ẑen en 50€.
*   **Sa Déclaration :** Il inscrit "50€" dans son registre des recettes et les déclare à l'URSSAF.

### **2. Pour le Capitaine**
*   **Son Revenu :** Il reçoit 2x la PAF pour son travail de maintenance + le surplus des loyers de son essaim. C'est sa rémunération.
*   **Le Processus :** Il accumule des Ẑen sur son MULTIPASS. Il décide de convertir 300 Ẑen en 300€ pour ses dépenses personnelles.
*   **Sa Déclaration :** Il inscrit "300€" dans son registre des recettes et les déclare.

### **3. Pour l'Utilisateur (qui convertit 1/3 de ses Ẑen)**
*   **Son Revenu :** Il a gagné 150 Ẑen grâce aux "likes" sur ses publications.
*   **Le Processus :** Il a le droit de convertir `150 / 3 = 50 Ẑen` cette année. Il utilise le "Pont de Liquidité" pour convertir ces 50 Ẑen en 50€.
*   **Sa Déclaration :** S'il s'agit d'un gain occasionnel, il peut le déclarer en **"revenu non commercial non professionnel"** sur sa déclaration annuelle. Si cela devient régulier, il est fortement encouragé à passer en Micro-Entrepreneur pour plus de clarté.

---

### **Le Statut de Base : Micro-Entrepreneur (BNC) - Notre Recommandation**

Pour démarrer, ce régime est imbattable.
*   **Coût :** 0€ pour la création.
*   **Comptabilité :** Tenir un simple registre des recettes en EUROS.
*   **Fiscalité :** On paie des cotisations et des impôts uniquement sur ce qu'on a **réellement encaissé en euros**.

**La règle d'or à retenir :** On ne déclare pas des Ẑen. On déclare les **EUROS** reçus sur son compte en banque après avoir utilisé le service de conversion ("Pont de Liquidité") de la coopérative.

---

### **Simulation 1 : Fred est Armateur/Capitaine d'un Satellite RPi**

*   **Investissement Initial :** Fred apporte un RPi5 + 4To. Valeur : **500€**.
*   **Son Capital Ẑen :** Sa `ZenCard` est créditée de **500 Ẑen**. C'est son capital de départ.
*   **Hypothèse d'Activité :** Son nœud est attractif. Il héberge :
    *   10 Sociétaires (qui ont acheté une part à 50€/an).
    *   50 Locataires MULTIPASS (à 1 Ẑen/semaine).
*   **Calcul de ses Revenus Annuels en Ẑen :**
    *   **Sa propre Rémunération (3xPAF) :** La PAF pour un RPi est fixée (disons 10 Ẑen/semaine). Il touche donc 30 Ẑen/semaine. Soit `30 * 52 = 1560 Ẑen/an`.
    *   **Revenus Locatifs :** 50 locataires * 1 Ẑen/semaine * 52 semaines = `2600 Ẑen/an`.
    *   **Total Brut en Ẑen :** `1560 + 2600 = 4160 Ẑen/an`.
    *   **Charges (PAF à payer au Node) :** `-10 * 52 = -520 Ẑen/an`.
    *   **Revenu Net en Ẑen :** `4160 - 520 = 3640 Ẑen`.
*   **Conversion en Euros :** Fred a besoin de liquidités. Il décide de convertir **2000 Ẑen** en **2000€** via la coopérative. C'est son **chiffre d'affaires déclarable**.
*   **Analyse Fiscale (Régime Micro-BNC) :**
    *   **Chiffre d'Affaires :** 2000€.
    *   **Abattement Forfaitaire pour Frais (34%) :** 680€.
    *   **Revenu Imposable :** `2000 - 680 = 1320€`.
    *   **Ses Frais Réels :** Son abonnement internet (disons 360€/an) + électricité (~100€/an) = **460€**.
    *   **Conclusion :** `460€ (frais réels) < 680€ (abattement)`. Le régime Micro-Entrepreneur est **extrêmement avantageux** pour lui.

---

### **Simulation 2 : Fred est Armateur/Capitaine d'un Hub PC Gamer**

*   **Investissement Initial :** Fred apporte un PC Gamer d'occasion. Valeur : **2000€**.
*   **Son Capital Ẑen :** Sa `ZenCard` est créditée de **2000 Ẑen**.
*   **Hypothèse d'Activité :** Son nœud est complet. Il héberge :
    *   24 Sociétaires.
    *   250 Locataires MULTIPASS.
*   **Calcul de ses Revenus Annuels en Ẑen :**
    *   **Sa propre Rémunération (3xPAF) :** La PAF pour un PC est plus élevée (disons 30 Ẑen/semaine). Il touche donc 90 Ẑen/semaine. Soit `90 * 52 = 4680 Ẑen/an`.
    *   **Revenus Locatifs :** 250 locataires * 1 Ẑen/semaine * 52 semaines = `13000 Ẑen/an`.
    *   **Total Brut en Ẑen :** `4680 + 13000 = 17680 Ẑen`.
    *   **Charges (PAF à payer au Node) :** `-30 * 52 = -1560 Ẑen/an`.
    *   **Revenu Net en Ẑen :** `17680 - 1560 = 16120 Ẑen`.
*   **Conversion en Euros :** Fred a des revenus conséquents. Il convertit **12000 Ẑen** en **12000€**. C'est son **chiffre d'affaires déclarable**.
*   **Analyse Fiscale (Régime Micro-BNC) :**
    *   **Chiffre d'Affaires :** 12000€.
    *   **Abattement Forfaitaire (34%) :** 4080€.
    *   **Revenu Imposable :** `12000 - 4080 = 7920€`.
    *   **Ses Frais Réels (1ère année) :** L'amortissement comptable de son PC (disons sur 3 ans, soit ~667€/an) + fibre pro (600€/an) + électricité (400€/an) = **~1667€**.
    *   **Conclusion :** `1667€ (frais réels) < 4080€ (abattement)`. Le régime Micro-BNC reste **très avantageux**, même avec un gros investissement. Il ne devient moins intéressant que si les frais réels (par exemple, si Fred louait un local dédié) dépassaient 34% de ses revenus.

---

### **Les "Traces à Suivre" : Comment le Système Génère vos Justificatifs**

C'est là que notre modèle prend tout son sens. **Vous n'avez pas à "suivre" les traces. Le système les génère pour vous.**

Notre infrastructure utilise les transactions sur **Open Collective** et sur les **wallets Ẑen** pour créer des exports automatisés, prêts à être transmis à l'administration.

#### **Solution Proposée : Le "Tableau de Bord Fiscal" du Capitaine**

Directement accessible depuis le Terminal Astroport (ou une future interface web), chaque membre pourra accéder à son tableau de bord et exporter des documents officiels.

#### **Export N°1 : Le Registre des Recettes (Pour votre déclaration Micro-BNC)**
C'est le document clé. En un clic, le système génère un fichier CSV ou PDF qui ressemble à ça :

| Date | Libellé | Montant Ẑen Converti | Montant EUR Reçu | Justificatif (Lien) |
| :--- | :--- | :--- | :--- | :--- |
| 15/02/2025 | Conversion Rémunération Capitaine | 300 Ẑen | 300,00 € | [lien vers tx sur OpenCollective] |
| 28/03/2025 | Conversion PAF Armateur | 50 Ẑen | 50,00 € | [lien vers tx sur OpenCollective] |
| ... | ... | ... | ... | ... |
| **TOTAL À DÉCLARER** | | | **XXX,XX €** | |

Ce document est la **preuve irréfutable** de vos revenus. Vous n'avez qu'à reporter le total dans votre déclaration URSSAF.

#### **Export N°2 : Le Relevé de Compte Courant d'Associé**
Ce document interne à la coopérative vous montre comment votre capital a "travaillé".

| Date | Opération | Revenus (MULTIPASS) | Charges (PAF) | Prélèvement Capital (ZenCard) | Solde Capital (ZenCard) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 07/01/2025 | Paiement PAF | +10 Ẑen | -15 Ẑen | **-5 Ẑen** | 1995 Ẑen |
| 14/01/2025 | Paiement PAF | +20 Ẑen | -15 Ẑen | **0 Ẑen** | 1995 Ẑen |

Ce relevé prouve le mécanisme de "compte courant d'associé automatisé". C'est un outil de gestion puissant pour l'opérateur et un gage de transparence totale.

#### **Export N°3 : Le Justificatif d'Apport en Capital**
Pour les Sociétaires, le système peut générer un PDF certifié :
> "La SCIC CopyLaRadio certifie que `Prénom Nom` (clé Ğ1 : `G1...`) a réalisé un apport en capital de **50 Ẑen** (cinquante Zen) le `jj/mm/aaaa`, lui conférant le statut de Sociétaire."

### **Conclusion : L'Infrastructure comme Expert-Comptable**

L'écosystème UPlanet n'est pas qu'une infrastructure technique ; c'est une **infrastructure administrative et fiscale**. Il est conçu pour que l'entrepreneuriat ne soit plus une charge mentale.

1.  **Le Régime le plus Adapté :** Commencez en **Micro-Entrepreneur (BNC)**. C'est simple, peu coûteux et avantageux dans la majorité des cas simulés.
2.  **Les Traces à Utiliser :** Ne les cherchez pas. Laissez le système les **générer pour vous** via le Tableau de Bord Fiscal.
3.  **La Solution :** Notre infrastructure est la solution. Elle utilise les données d'**Open Collective** (pour les flux en €) et des **wallets Ẑen** (pour les flux internes) pour créer des **exports comptables prêts à l'emploi**.

Le but est de vous libérer de la complexité pour que vous puissiez vous concentrer sur ce qui compte : bâtir un internet décentralisé et une économie régénératrice.

