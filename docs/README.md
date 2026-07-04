# Documentation Astroport.ONE

Organisée selon le standard [Diátaxis](https://diataxis.fr/) — quatre types de contenu, chacun à sa place.

***

## Quintette — Documentation transversale (tous modes Diataxis)

| Fichier                      | Sujet                                                                                                                                                            |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [quintette.md](quintette.md) | **`feedback` · `issue` · `commit` · `cpscript` · `cpcode`** — De la panne terrain au correctif Git : tutorial, guides, référence et explication du cycle complet |

***

## Tutorials — Apprentissage

> Guides pas-à-pas pour apprendre en faisant. Destinés aux débutants. → [Voir le README complet du quadrant](tutorials/)

### 🚀 Par où commencer ?

**→** [**🎟️ Créer son MULTIPASS UPlanet**](tutorials/MULTIPASS_INSCRIPTION.md) Rejoindre l'écosystème en 5 à 10 minutes : identité NOSTR, portefeuille Ğ1, uDRIVE 10 Go, Kin Maya. Premier tutoriel recommandé pour tout nouvel utilisateur.

| Fichier                                                         | Sujet                                                                                     |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| [MULTIPASS\_INSCRIPTION.md](tutorials/MULTIPASS_INSCRIPTION.md) | **🎟️ Créer son MULTIPASS** — identité NOSTR, portefeuille Ğ1, Kin Maya (5–10 min)        |
| [WOTX2\_DEMO\_SCENARIO.md](tutorials/WOTX2_DEMO_SCENARIO.md)    | **Scénario WoTx² complet** — 6 personas, crafting social, médiation, assurance mutualiste |
| [install\_baremetal.md](tutorials/install_baremetal.md)         | Installer sur Linux (Debian/Ubuntu/Mint) — métal nu                                       |
| [install\_docker.md](tutorials/install_docker.md)               | Installer avec Docker — profils standard, cloud, ai                                       |
| [setup\_learning\_hub.md](tutorials/setup_learning_hub.md)      | Transformer sa station en hub d'apprentissage IA (Nextcloud + Qdrant + BRO)               |
| [PC\_GAMER\_HUB\_GUIDE.md](tutorials/PC_GAMER_HUB_GUIDE.md)     | Convertir un PC gamer en station Astroport rentable (Linux Mint + IA)                     |
| [README.NostrTube.DEV.md](tutorials/README.NostrTube.DEV.md)    | Développer des applications sur la plateforme vidéo NostrTube                             |
| [BASH\_BEST\_PRACTICES.md](tutorials/BASH_BEST_PRACTICES.md)    | Bonnes pratiques de sécurité et robustesse pour les scripts Bash                          |

***

## How-To — Recettes

> Guides orientés tâche pour résoudre un problème précis. Supposent des connaissances de base. → [Voir le README complet du quadrant](how-to/)

| Fichier                                                                     | Sujet                                                                                           |
| --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [LOCAL\_BIN\_SYMLINKS.md](how-to/LOCAL_BIN_SYMLINKS.md)                     | Commandes du Capitaine : inventaire `~/.local/bin`, journal `~/.zen/.astro`, convention d'ajout |
| [ASTROSYSTEMCTL.md](how-to/ASTROSYSTEMCTL.md)                               | Télécommander des services P2P via tunnels IPFS                                                 |
| [SWARM\_WIREGUARD.md](how-to/SWARM_WIREGUARD.md)                            | VPN constellation WireGuard — rejoindre l'essaim, contourner CGNAT, abonnements services        |
| [DRAGONS\_and\_TUNNELS.md](how-to/DRAGONS_and_TUNNELS.md)                   | Publier et découvrir des services IA entre stations (DRAGONS + modules.list)                    |
| [API.NOSTRAuth.readme.md](how-to/API.NOSTRAuth.readme.md)                   | Authentification NOSTR NIP-42 côté serveur et client                                            |
| [NOSTR\_GET\_EVENTS.md](how-to/NOSTR_GET_EVENTS.md)                         | Interroger la base de données du relay NOSTR local                                              |
| [README\_YOUTUBE.md](how-to/README_YOUTUBE.md)                              | Gestion vidéo UPlanet : téléchargement manuel, sync auto, webcam                                |
| [VOCALS\_SYSTEM.md](how-to/VOCALS_SYSTEM.md)                                | Messages vocaux chiffrés sur NOSTR avec géolocalisation                                         |
| [POWER\_MONITORING.md](how-to/POWER_MONITORING.md)                          | Surveiller la consommation électrique des processus (PowerJoular)                               |
| [COLLABORATIVE\_COMMONS\_SYSTEM.md](how-to/COLLABORATIVE_COMMONS_SYSTEM.md) | Co-rédiger et valider des documents communs territoriaux                                        |
| [PLANTNET\_SYSTEM.md](how-to/PLANTNET_SYSTEM.md)                            | Cataloguer la biodiversité et ressources locales                                                |
| [MINELIFE.md](how-to/MINELIFE.md)                                           | Crafting décentralisé des compétences WoTx2 (interface Minecraft)                               |
| [REPORT\_FRICTION.md](how-to/REPORT_FRICTION.md)                            | Déclarer une friction WoTx² et suivre la médiation N1/N2                                        |
| [CODEBASE\_EMBEDDINGS.md](how-to/CODEBASE_EMBEDDINGS.md)                    | Mémoire vectorielle du code (Qdrant + nomic-embed-text + snapshot IPFS)                         |
| [KNOWLEDGE\_EMBEDDINGS.md](how-to/KNOWLEDGE_EMBEDDINGS.md)                  | Mémoire vectorielle des connaissances WoTx2 (.md/.pdf depuis Kind 30504, uDRIVE, Nextcloud)     |
| [GRIMOIRE\_LIVE.md](how-to/GRIMOIRE_LIVE.md)                                | Vidéo WoTx2 : génération automatique + live streaming (vdo.ninja, NIP-53)                       |
| [config\_wireguard\_vpn.md](how-to/config_wireguard_vpn.md)                 | Configurer WireGuard pour la communication inter-stations                                       |
| [print\_multipass\_cards.md](how-to/print_multipass_cards.md)               | Générer et imprimer les QR codes MULTIPASS et ZenCards                                          |
| [publish\_nostrtube\_video.md](how-to/publish_nostrtube_video.md)           | Publier une vidéo sur NostrTube (IPFS + kind 21)                                                |
| [youtube\_archive\_open\_with.md](how-to/youtube_archive_open_with.md)      | Archiver YouTube dans son uDRIVE via l'extension Firefox "Open With"                            |

***

## Reference — Information brute

> Données techniques sèches : formats, specs, listes, endpoints. Source de vérité. → [Voir le README complet du quadrant](reference/)

| Fichier                                                                          | Sujet                                                                             |
| -------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| [NOSTR\_EVENTS\_REFERENCE.md](reference/NOSTR_EVENTS_REFERENCE.md)               | **Référence centrale** des kinds NOSTR utilisés dans UPlanet                      |
| [A4L\_GEO\_TAGGING.md](reference/A4L_GEO_TAGGING.md)                             | **Format `a4l:` propriétaire ATOM4LOVE** — adressage hexagonal Goldberg sur NOSTR |
| [IDENTITY\_MULTIPASS.md](reference/IDENTITY_MULTIPASS.md)                        | Identité niveau 1 — MULTIPASS : structure, champs, lifecycle                      |
| [IDENTITY\_ZENCARD.md](reference/IDENTITY_ZENCARD.md)                            | Identité niveau 2 — ZenCard : droits, ressources, propriété                       |
| [INFO\_JSON\_FORMATS.md](reference/INFO_JSON_FORMATS.md)                         | Format de métadonnées `info.json` v2.0 pour les fichiers IPFS                     |
| [Analytics.README.md](reference/Analytics.README.md)                             | Système analytique `astro.js` — kind 10600 (HTTP, NOSTR, chiffré)                 |
| [COOKIE\_SYSTEM.md](reference/COOKIE_SYSTEM.md)                                  | Gestion universelle de cookies pour l'authentification scrapers                   |
| [DOMAIN\_SCRAPERS.md](reference/DOMAIN_SCRAPERS.md)                              | Architecture des scrapers automatiques basés sur les cookies                      |
| [ZEN.INTRUSION.POLICY.md](reference/ZEN.INTRUSION.POLICY.md)                     | Politique de gestion des fonds externes — architecture portefeuilles              |
| [ROAMING\_UDRIVE\_SYNC.md](reference/ROAMING_UDRIVE_SYNC.md)                     | Protocole de synchronisation uDRIVE inter-stations                                |
| [JOURNAUX\_N2\_NOSTRCARD.md](reference/JOURNAUX_N2_NOSTRCARD.md)                 | Journaux N² générés automatiquement par MULTIPASS                                 |
| [WOTX2\_SYSTEM.md](reference/WOTX2_SYSTEM.md)                                    | Toiles de confiance duales Oracle + P2P, objets partagés, médiation, 6 personas   |
| [KIND\_30505\_OBJECTS.md](reference/KIND_30505_OBJECTS.md)                       | Spec objets WoTx² — quantity model, durability, quorum, crafting social           |
| [KIND\_30506\_JUSTICE.md](reference/KIND_30506_JUSTICE.md)                       | Spec médiation WoTx² — dossier 30506, actes 1506, assurance mutualiste            |
| [UPlanet\_FILE\_CONTRACT.md](reference/UPlanet_FILE_CONTRACT.md)                 | Protocole de gestion décentralisée des fichiers IPFS+NOSTR                        |
| [UPlanet\_CROWDFUNDING\_CONTRACT.md](reference/UPlanet_CROWDFUNDING_CONTRACT.md) | Protocole de financement participatif décentralisé                                |
| [upassport\_api\_endpoints.md](reference/upassport_api_endpoints.md)             | Endpoints UPassport (port 54321) — routers FastAPI, route /qr                     |
| [bash\_scripts\_roles.md](reference/bash_scripts_roles.md)                       | Rôle fonctionnel de chaque script Bash du projet                                  |
| [cli\_keygen\_commands.md](reference/cli_keygen_commands.md)                     | Référence CLI `keygen` — dérivation déterministe G1/IPFS/NOSTR                    |

***

## Explanation — Philosophie et contexte

> Discussions de fond : pourquoi, comment on en est arrivé là, les choix d'architecture. → [Voir le README complet du quadrant](explanation/)

| Fichier                                                              | Sujet                                                                                                  |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| [ZEN.ECONOMY.v3.md](explanation/ZEN.ECONOMY.v3.md)                   | **Source canonique** — Économie ẐEN v3 : boucle Ğ1↔ẐEN↔❤️, TrocZen                                     |
| [ROLES.md](explanation/ROLES.md)                                     | Rôles Armateur / Capitaine — responsabilités et droits                                                 |
| [DID\_IMPLEMENTATION.md](explanation/DID_IMPLEMENTATION.md)          | Identités décentralisées W3C DID, UCAN, clés SSSS 3/2                                                  |
| [ORE\_SYSTEM.md](explanation/ORE_SYSTEM.md)                          | Cadastre écologique décentralisé — obligations environnementales NOSTR                                 |
| [ORACLE\_SYSTEM.md](explanation/ORACLE_SYSTEM.md)                    | Certification de compétences WoT — attestations multi-signatures                                       |
| [N2\_MEMORY\_SYSTEM.md](explanation/N2_MEMORY_SYSTEM.md)             | Prise de décision collective N² — jeu de l'ange de Conway                                              |
| [CROWDFUNDING\_COMMUNS.md](explanation/CROWDFUNDING_COMMUNS.md)      | Financement participatif des biens communs (terrains, équipements)                                     |
| [BRO\_RAG\_PERSONAL.md](explanation/BRO_RAG_PERSONAL.md)             | Architecture de l'assistant IA souverain #BRO (RAG personnel)                                          |
| [README.NostrTube.md](explanation/README.NostrTube.md)               | NostrTube — vision de la plateforme vidéo décentralisée                                                |
| [architecture\_overview.md](explanation/architecture_overview.md)    | Vue synthétique : IPFS+NOSTR+Ğ1, flux de données, couches fondamentales                                |
| [minelife\_wikipedia\_wot.md](explanation/minelife_wikipedia_wot.md) | MineLife comme Wikipédia décentralisé — WoT relativiste, Capitaine bibliothécaire, effet constellation |
| [ANALYTICS.md](explanation/ANALYTICS.md)                             | Analytics décentralisé — Kind 10600 + NIP-44, zéro fuite vers les GAFAM                                |
| [ASYNC\_TASKS\_NOSTR.md](explanation/ASYNC_TASKS_NOSTR.md)           | Tâches asynchrones inter-NODE via DMs NOSTR — le "RabbitMQ Web3"                                       |
| [WOTX2\_MEDIATION.md](explanation/WOTX2_MEDIATION.md)                | Assurance mutualiste WoT — pourquoi la médiation pair-à-pair remplace l'assurance centralisée          |

***

## Archive

> Fichiers obsolètes, doublons, ou en cours de refonte. Ne pas utiliser comme référence.

| Fichier                                                                | Raison                                   |
| ---------------------------------------------------------------------- | ---------------------------------------- |
| [ZEN.ECONOMY.v3.md](explanation/ZEN.ECONOMY.v3.md) ← **utiliser ceci** | —                                        |
| [ZEN.ECONOMY.readme.md](archive/ZEN.ECONOMY.readme.md)                 | Remplacé par v3                          |
| [ZEN.ECONOMY.v2.md](archive/ZEN.ECONOMY.v2.md)                         | Remplacé par v3                          |
| [uMARKET.md](archive/uMARKET.md)                                       | En refonte — migration vers contrats ORE |
| [uMARKET.todo.md](archive/uMARKET.todo.md)                             | Tâches de refonte uMARKET                |

***

## Contrats

| Fichier                                                           | Sujet                                           |
| ----------------------------------------------------------------- | ----------------------------------------------- |
| [contrats/COMMODAT\_ASTROPORT.md](contrats/COMMODAT_ASTROPORT.md) | Contrat de commodat pour les stations Astroport |

***

## Dev Logs

> Notes de travail internes, plans de migration, systèmes en cours de refonte. Ne pas utiliser comme référence publique.

| Fichier                                                                               | Sujet                                                            |
| ------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| [TODO.md](https://github.com/papiche/Astroport.ONE/blob/master/docs/dev_logs/TODO.md) | TODO principal Astroport.ONE (système à refondre)                |
| [TODO\_SYSTEM.md](dev_logs/TODO_SYSTEM.md)                                            | Documentation du système TODO N² (déprécié — todo.sh en refonte) |
| [TODO\_MIGRATION\_RNOSTR\_SEMANTIC.md](dev_logs/TODO_MIGRATION_RNOSTR_SEMANTIC.md)    | Plan de migration strfry → rnostr + Qdrant sémantique            |
