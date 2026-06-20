# BRO — Guide ATOM4LOVE : rencontres, fonctions et protocole

## Qu'est-ce qu'ATOM4LOVE ?

ATOM4LOVE est un protocole de rencontres décentralisé basé sur la physique vibratoire.
Chaque personne a une "phase personnelle" φ calculée depuis sa date, heure et lieu de naissance.
Le "taux de cohérence k" entre deux personnes mesure l'alignement de leurs phases (0 à 1).

## Comment faire des rencontres avec ATOM4LOVE ?

**Étape 1 — Créer son profil ATOM :**
- Aller sur `atomic.html` (UPlanet earth/)
- Saisir date, heure, lieu de naissance
- Ton KIN Maya (1-260) et ta phase φ sont calculés
- Publication Kind 30078 `d=atom4love` sur NOSTR

**Étape 2 — Partager ton lien de résonance :**
- `atomic_match.html?p=base64(JSON)` — envoie ce lien à quelqu'un
- Il/elle voit le score de cohérence k entre vous deux
- Score > 85% : match vibratoire fort

**Étape 3 — Rencontre physique avec cabine-33 :**
- L'app `cabine-33` scanne les signaux BLE/WiFi nommés `A4L-*`
- k ≥ 0.85 → Kind 30508 (Match vibratoire)
- k ≥ 0.95 → Kind 30502 (Atom4Peace bond)
- Rituel de Phase (33 secondes) → Kind 30503 skill géolocalisé

## Fonctions disponibles

| Fonction | Fichier | Rôle |
|----------|---------|------|
| Calcul φ et KIN | `atomic.html` | Phase personnelle + calendrier Maya |
| Lien de résonance | `atomic_match.html` | Partage du score k avec n'importe qui |
| Carte des atomes | `atomic_map.html` | Visualisation géographique des profils |
| Résonance de groupe | `atomic_choir.html` | Score d'harmonie pour N personnes |
| Rencontre physique | `cabine-33` app | BLE/WiFi scan + rituel de phase |

## Comment utiliser BRO pour explorer ATOM4LOVE ?

Tu peux demander à BRO en DM NOSTR :
- "quel est mon KIN Maya ?" → BRO te demande ta date de naissance
- "explique la phase phi2x" → explication du moteur Phi2X
- "comment calculer la cohérence k ?" → formule mathématique
- "comment partager mon profil atomique ?" → lien atomic_match.html

## Mots-clés pour chercher dans BRO

`phi2x`, `KIN Maya`, `phase vibratoire`, `cohérence k`, `atomic.html`,
`cabine-33`, `Kind 30078`, `atom4love`, `rencontre décentralisée`, `Phi2X.computeResonanceK`

## Niveaux WoT ATOM4LOVE

- **WoT Level 0** : Visiteur Atomique — Kind 30078 sans MULTIPASS
- **WoT Level 1** : MULTIPASS — φ + ω stockés dans DID Kind 30800
- **WoT Level 2** : Résonance physique — cabine-33 BLE/WiFi + rituel 33s
