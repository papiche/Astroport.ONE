# Rapport d'intervention – TiddlyWiki / API netcat / ZENCard → MULTIPASS (nostr)

**Date:** 2026-02-01  
**Périmètre:** Astroport.ONE – documentation `.md` et workflow applicatif (20h12, RUNTIME)

---

## 1. Contexte et évolution

### 1.1 Ancien modèle (TW + API netcat)

- **TiddlyWiki (TW)** servait de **base de données distribuée** pour les joueurs (PLAYER) et la ZENCard (carte recueillant le capital ẐEN bâtisseurs).
- **API sur port 1234** : chaque station exposait une API BASH via **netcat** (`nc -l -p 1234 -q 1`), routée par `12345.sh`. Les scripts du répertoire **`/API`** (PLAYER.sh, ZONE.sh, QRCODE.sh, SALT.sh, UPLANET.sh, etc.) géraient les interactions avec les TW des joueurs (export tiddlers, zones géo, création ZenCards/AstroIDs).
- **ZENCard** : identité économique (UPLANET wallet + TW) ; capital ẐEN ; stockage/cache lié au TW (ex. `~/.zen/tmp/${IPFSNODEID}/TW/${PLAYER}/`).
- **Rafraîchissement UPlanet** : `_UPLANET.refresh.sh` mettait à jour les UMAP (clés géo), secteurs/régions, et s’appuyait sur des structures créées par PLAYER.refresh (TW/IPFS).

### 1.2 Modèle actuel (nostr / MULTIPASS)

- **MULTIPASS** remplace progressivement le rôle “identité + stockage” tenu par TW pour les usagers (NOSTR + DID + uDRIVE 10GB, ZEN Card = MULTIPASS + services payants).
- **Données et sync** : événements NOSTR (relays, strfry), pas TW comme base de données principale.
- **Rafraîchissement** : `_UPLANET.refresh.sh` est **désactivé** dans le workflow 20h12 (UX/UI inadaptées). Le flux UPlanet ẐEN repose sur :
  - `NOSTRCARD.refresh.sh` (MULTIPASS),
  - `PLAYER.refresh.sh` (ZEN Cards),
  - `UPLANET.refresh.sh` (clés géo UMAP/SECTOR/REGION, mode actif).

---

## 2. Références trouvées dans la documentation

### 2.1 TiddlyWiki (TW)

| Fichier | Référence | Contexte |
|---------|-----------|----------|
| **README.TW.md** | TW + clé + email, API port 1234, sync 20h12 | Décrit l’ancien modèle (API par ordinateur, TW par PLAYER). **À clarifier : obsolète ou “legacy”** |
| **RUNTIME/TW/readme.md** | “TiddlyWiki acts as a distributed object database” | Outils CLI import/delete tiddler ; toujours valide si TW reste utilisé ponctuellement. |
| **DOCUMENTATION.md** | Lien “Runtime TW” (RUNTIME/TW/readme.md) | Référence runtime TW. |
| **SUMMARY.md** | Section “Runtime & TiddlyWiki” → Runtime TW | Idem. |
| **ARCHITECTURE.md** | “G1PalPay.sh - Surveillance TW quotidienne”, “Cache IPFS du TW de la ZenCard”, “API Gateway (Port 1234)” | Mélange ancien (TW, 1234) et actuel. **Incohérent** avec 20h12 (pas d’appel _UPLANET.refresh, port 1234 deprecated). |
| **docs/ZEN.ECONOMY.readme.md** | “Services : Accès TiddlyWiki + 128Go”, “128Go NextCloud + TW + NOSTR” | Liste TW comme service ZEN Card. **À aligner** : préciser si TW est optionnel/legacy et que la “base de données” identité/sync est NOSTR. |
| **API.NOSTRAuth.readme.md** | `tw_feed`, chemins `~/.zen/tmp/.../TW/${email}/`, “Flux TiddlyWiki” | Profil NOSTR peut encore exposer un tw_feed ; chemins TW en cache. **À marquer legacy/optionnel** si plus central. |
| **BOOKS/api/README.md**, **BOOKS/api/player.sh.md** | PLAYER.sh dans `/API`, opérations liées aux TW (export tiddlers, médias TW) | Documentation **API legacy** (port 1234, TW). À labelliser “Legacy / API v1”. |
| **BOOKS/Readme.U.md** | “MULTIPASS = ZenCard - UPLANET wallet + TW” | Réduit ZEN Card à “wallet + TW”. **Incohérent** avec MULTIPASS = identité NOSTR + uDRIVE ; TW ne doit plus être le cœur de la définition. |
| **BOOKS/astroport-20h12/** (plusieurs .md) | player.refresh, voeux, sector/region refresh, tiddlywiki --load, TW des joueurs | Décrivent l’ancien flux basé TW. **À mettre à jour** pour refléter NOSTR/MULTIPASS et indiquer ce qui reste optionnel (TW). |
| **README.old.md** | “REC … Capsule in your TW”, “port 1234 publishes API”, “netcat”, “Astroport doesn’t need a web server … netcat” | Ancien modèle explicite. **Conserver comme historique** ou déplacer en “archive”. |
| **DID_IMPLEMENTATION.md** | “Synchronisation TiddlyWiki : Gestion des données personnelles” | À préciser : si sync identité/données passe par NOSTR, retirer ou restreindre à “optionnel TW”. |
| **UPLANET.init.README.md**, **SCRIPTS.ROLES.md**, **EMBARQUEMENT.md** | `nostr_DESTROY_TW.sh`, désinscription | Script de destruction/compte ; nom garde “TW” mais cible MULTIPASS/ZEN Card. Pas d’ambiguïté majeure. |
| **RUNTIME/NOSTRCARD.cursor.md** | Chemins `~/.zen/tmp/.../TW/${PLAYER}/` (HEX, GPS, NPUB, G1PUBNOSTR), `nostr_DESTROY_TW.sh` | Chemins de cache ; nom “TW” = répertoire legacy. À documenter comme convention de chemins, pas comme “base de données TW”. |

### 2.2 API netcat / port 1234 / répertoire /API

| Fichier | Référence | Contexte |
|---------|-----------|----------|
| **README.old.md** | `nc -l -p 1234 -q 1`, “API (REPONSE PORT …)”, “Requests are made in HTTP GET on port 1234” | Ancien modèle netcat. **Historique.** |
| **README.TW.md** | “Chaque ordinateur sert l’API sur le port 1234” | Cohérent avec ancien modèle. |
| **ARCHITECTURE.md** | “12345.sh \| 10KB \| 1234”, “Port 1234 \| Twist API \| Twist BASH API (deprecated)”, “API Gateway (Port 1234)” | **Correct** : 1234 marqué deprecated. À vérifier que toutes les mentions “API” pour 1234 sont bien “deprecated” ou “legacy”. |
| **BOOKS/api/README.md** | “répertoire /API … interface API” | Pas de mention netcat/1234 ; à labelliser “Legacy API (v1)” et indiquer remplacement (UPassport/54321, NOSTR). |
| **BOOKS/api/player.sh.md** | “PLAYER.sh dans le répertoire /API” | Idem, legacy. |
| **tools/MULTIPASS_SYSTEM.md** | “Local: `http://{hostname}:1234`” | À nuancer : 1234 deprecated ; préférer UPassport/54321 ou NOSTR. |
| **EMBARQUEMENT.md** | “Ports … Astroport (1234)” | À marquer deprecated. |
| **WELCOME.md** | “API et développement” (lien API.NOSTRAuth) | OK. |

### 2.3 ZENCard et capital ẐEN

- **ZENCard** : bien documentée comme identité économique (capital ẐEN, loyers, PLAYER.refresh.sh) dans **docs/ZEN.ECONOMY.readme.md**, **SCRIPTS.ROLES.md**, **captain.sh**, **uplanet_onboarding.sh**, **UPLANET.official.sh**, **tools/nostr_DESTROY_TW.sh**, etc.
- **Lien ZENCard–TW** encore présent dans :
  - **docs/ZEN.ECONOMY.readme.md** : “Services : Accès TiddlyWiki + 128Go” pour ZEN Cards.
  - **ARCHITECTURE.md** : “Cache IPFS du TW de la ZenCard”.
  - **BOOKS/Readme.U.md** : “MULTIPASS = ZenCard - UPLANET wallet + TW”.
- **Alignement recommandé** : ZEN Card = MULTIPASS + services payants + capital ẐEN ; TW = optionnel ou legacy, pas “base de données” du capital.

### 2.4 Script _UPLANET.refresh.sh et workflow 20h12

| Fichier | Référence | Contexte |
|---------|-----------|----------|
| **20h12.process.sh** | L.243–247 : si pas EnfinLibre, exécute `PLAYER.refresh.sh` puis **commentaire** “# ${MY_PATH}/RUNTIME/_UPLANET.refresh.sh - old methods -” | **Source de vérité** : _UPLANET.refresh désactivé, remplacé par PLAYER.refresh + UPLANET.refresh (geo). |
| **_12345.sh** | “IPNS flashmem desactivated - reactivate as needed - _UPLANET.refresh.sh TW system” | Cohérent : flashmem / ancien système TW désactivé. |
| **RUNTIME/ORACLE.refresh.sh** | Réutilise logique STRAPFILE “same as _UPLANET.refresh.sh” | Référence interne OK (extraction STRAPS). |
| **docs/WOTX2_SYSTEM.md** | Détection bootstrap “même logique que _UPLANET.refresh.sh” | OK. |
| **docs/POWER_MONITORING.md**, **tools/power_monitor.sh** | 20h12 nettoie ~/.zen/tmp | OK. |

**Workflow applicatif 20h12 (résumé pertinent) :**

1. Power monitoring, solar time, vérification IPFS.
2. Copie des logs, nettoyage ~/.zen/tmp (en préservant swarm, flashmem, coucou).
3. Arrêt astroport, mise à jour dépôts (G1BILLET, UPassport, NIP-101, Astroport, OC2UPlanet, silkaj, yt-dlp), ping bootstrap.
4. **NOSTRCARD.refresh.sh** (MULTIPASS).
5. Si **UPLANETNAME != "EnfinLibre"** : **PLAYER.refresh.sh** (ZEN Cards) ; **_UPLANET.refresh.sh** **non exécuté** (commenté).
6. **UPLANET.refresh.sh** (clés UMAP / SECTOR / REGION).
7. Nettoyage tmp, bootstrap IPFS, gestion LOWMODE IPFS, DRAGON_p2p_ssh, redémarrage astroport (12345.sh, etc.).

Aucune doc ne doit laisser croire que _UPLANET.refresh.sh est encore appelé dans le flux quotidien.

---

## 3. Incohérences et références dépassées

### 3.1 À corriger ou clarifier

1. **ARCHITECTURE.md**
   - “G1PalPay.sh - Surveillance **TW** quotidienne” : aujourd’hui surveillance Ğ1 + NOSTRCARD/PLAYER.refresh ; préciser que “TW” n’est plus le cœur du flux.
   - “Cache IPFS **du TW de la ZenCard**” : remplacer par “cache MULTIPASS/NOSTR (ex. chemins hérités TW)” ou “cache ZEN Card (legacy chemins TW)”.
   - Port 1234 : déjà “deprecated” ; vérifier qu’aucune phrase n’implique que 1234 est le standard actuel.

2. **docs/ZEN.ECONOMY.readme.md**
   - “Services : **Accès TiddlyWiki** + 128Go” pour ZEN Cards : indiquer “optionnel / legacy” ou “Accès NOSTR (MULTIPASS) + 128Go (TW si activé)”.
   - “128Go NextCloud **+ TW + NOSTR**” : ordre et rôle : NOSTR comme canal principal, TW optionnel.

3. **BOOKS/Readme.U.md**
   - “MULTIPASS = ZenCard - UPLANET wallet **+ TW**” : remplacer par une formule du type “ZEN Card = MULTIPASS + UPLANET wallet (+ services) ; TW optionnel/legacy”.

4. **README.TW.md**
   - Ajouter en en-tête une note : “Ce document décrit le modèle historique (API 1234, TW par station). Aujourd’hui, l’identité et la synchronisation reposent sur NOSTR (MULTIPASS).”

5. **DOCUMENTATION.md / SUMMARY.md**
   - Conserver le lien “Runtime TW” mais ajouter une phrase : “Utilitaires TW (optionnel/legacy). Données identité et sync : NOSTR (MULTIPASS).”

6. **BOOKS/api/README.md** et **BOOKS/api/player.sh.md**
   - Titre ou premier paragraphe : “**Legacy API (v1)** – Port 1234 / netcat désactivé. Pour l’authentification et les profils : UPassport (54321), NOSTR Auth.”

7. **BOOKS/astroport-20h12/** (README, player.refresh, voeux, uplanet.refresh, etc.)
   - Mentionner que le flux quotidien 20h12 n’utilise plus _UPLANET.refresh.sh ni TW comme base principale ; PLAYER.refresh.sh et NOSTRCARD.refresh.sh s’appuient sur NOSTR/MULTIPASS ; TW restant optionnel là où encore utilisé.

8. **DID_IMPLEMENTATION.md**
   - “Synchronisation TiddlyWiki : Gestion des données personnelles” : préciser “optionnel” ou remplacer par “Synchronisation NOSTR (MULTIPASS) ; export TW optionnel”.

9. **tools/MULTIPASS_SYSTEM.md**
   - “Local: `http://{hostname}:1234`” : préciser “Legacy (deprecated). Préférer UPassport (port 54321) ou NOSTR.”

10. **RUNTIME/NOSTRCARD.cursor.md**
    - Préciser que les chemins contenant “TW” sont des **conventions de répertoires** (cache) et ne signifient pas que TiddlyWiki est la base de données des identités (c’est NOSTR).

### 3.2 À conserver sans changement (ou mineur)

- **README.old.md** : conserver comme historique ; éventuellement renommer ou déplacer en “archive” et ajouter une ligne en tête “Documentation historique (API netcat, TW par station).”
- **RUNTIME/TW/readme.md** : garder tel quel si les scripts d’import/delete tiddler sont encore utilisés ; ajouter une ligne “Optional / legacy TW; primary identity data is NOSTR.”
- **UPLANET.init.README.md**, **SCRIPTS.ROLES.md**, **EMBARQUEMENT.md** : `nostr_DESTROY_TW.sh` peut garder son nom (cible MULTIPASS/ZEN Card) ; pas d’obligation de renommer.
- **API.NOSTRAuth.readme.md** : garder `tw_feed` et chemins TW comme optionnels/legacy dans le profil NOSTR.

---

## 4. Synthèse des interventions recommandées

| Priorité | Action | Fichiers concernés |
|----------|--------|--------------------|
| Haute | Marquer explicitement _UPLANET.refresh.sh comme “désactivé (old methods)” dans toute doc qui l’évoque comme actif | ARCHITECTURE, BOOKS/astroport-20h12, README.detail si mention |
| Haute | Préciser que la “base de données” identité / sync est NOSTR (MULTIPASS), TW optionnel/legacy | ARCHITECTURE, DOCUMENTATION, SUMMARY, README.TW, ZEN.ECONOMY.readme, DID_IMPLEMENTATION |
| Haute | Labelliser “Legacy / deprecated” l’API port 1234 et le répertoire /API | ARCHITECTURE, BOOKS/api/README, BOOKS/api/player.sh, MULTIPASS_SYSTEM, EMBARQUEMENT |
| Moyenne | Aligner définition ZEN Card : MULTIPASS : 128Go + services + ẐEN ; TW non central | BOOKS/Readme.U, ZEN.ECONOMY.readme, ARCHITECTURE |
| Moyenne | Mettre à jour BOOKS/astroport-20h12 pour refléter 20h12 actuel (sans _UPLANET.refresh, avec NOSTR/MULTIPASS) | README, player.refresh, voeux, uplanet.refresh, etc. |
| Basse | Clarifier chemins “TW” dans NOSTRCARD.cursor comme convention de cache | RUNTIME/NOSTRCARD.cursor.md |
| Basse | Note “historique” sur README.old (netcat/TW) | README.old.md |

---

## 5. Références croisées utiles

- **Workflow 20h12** : `20h12.process.sh` (l.236–254).
- **Désactivation _UPLANET.refresh** : `20h12.process.sh` l.247 (commentaire).
- **API legacy** : `README.old.md` (netcat, 1234), `ARCHITECTURE.md` (1234 deprecated), `BOOKS/api/`.
- **ZEN Card / MULTIPASS** : `tools/MULTIPASS_SYSTEM.md`, `docs/ZEN.ECONOMY.readme.md`, `BOOKS/Readme.U.md`.
- **Runtime TW** : `RUNTIME/TW/readme.md`, `DOCUMENTATION.md`, `SUMMARY.md`.

---

*Rapport généré pour alignement de la documentation avec l’évolution TW → NOSTR (MULTIPASS) et la désactivation de _UPLANET.refresh.sh dans le workflow 20h12.*
