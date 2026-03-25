# 👨‍✈️ Rôles du Réseau : Armateur & Capitaine

Le fonctionnement d'une station Astroport.ONE repose sur la distinction claire entre la responsabilité du matériel (physique) et la responsabilité du logiciel (logique).

## 🏗️ L'Armateur (Host / Matériel)
L'Armateur est celui qui fournit et entretient la machine physique (PC Gamer, Raspberry Pi, Serveur).

- **Responsabilités :**
    - Fournir l'électricité et une connexion Internet stable.
    - Assurer la maintenance matérielle (disques, ventilateurs).
    - Héberger physiquement le nœud IPFS.
- **Rémunération :**
    - Il reçoit la **PAF** (Participation Aux Frais), par défaut 14 Ẑen/semaine, pour couvrir les coûts réels d'exploitation.
- **Identité :** Il est identifié par la clé `UPLANETNAME_NODE`.

## 👨‍✈️ Le Capitaine (Operator / Logiciel)
Le Capitaine est le pilote de la station. C'est lui qui gère la couche logicielle Astroport.ONE.

- **Responsabilités :**
    - Configurer et mettre à jour les services (Astroport, Nostr, IPFS).
    - Valider l'embarquement des nouveaux passagers (création de MULTIPASS).
    - Modérer et curer les contenus relayés par la station.
    - Assurer le "Backfill" (synchronisation) de la constellation.
- **Rémunération :**
    - Il reçoit **2x la PAF** en reconnaissance de son service de maintenance et de curation.
- **Identité :** Défini par le lien `game/players/.current` -> `CAPTAINEMAIL`.

## 🤝 Le Contrat de Constellation
Dans une installation domestique, l'Armateur et le Capitaine sont souvent la même personne. Cependant, dans le cadre de la coopérative, un Armateur peut confier la gestion de sa machine à un Capitaine plus expérimenté. 

L'économie du nœud est arbitrée par le script `ZEN.ECONOMY.sh`, qui distribue automatiquement les revenus locatifs des MULTIPASS entre la trésorerie de la SCIC (33%), la R&D (33%) et le fonds d'amortissement de l'Armateur (33%).