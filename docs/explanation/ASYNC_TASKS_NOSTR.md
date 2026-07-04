# Tâches Asynchrones via DMs NOSTR — Le "RabbitMQ Web3"

## Pourquoi ce choix d'architecture

Les systèmes distribués ont besoin d'un bus de messages pour déléguer des tâches lourdes (génération d'images, transcription, synthèse vocale) à des nœuds spécialisés sans bloquer l'expéditeur. Les solutions classiques — Redis, RabbitMQ, Celery — nécessitent un serveur central, une authentification partagée, et une infrastructure réseau privée.

Astroport.ONE n'a rien de tout ça par conception. Chaque station est souveraine, sans IP publique fixe ni serveur centralisé. La question est donc : **comment orchestrer des calculs distribués dans un réseau pair-à-pair sans infrastructure centrale ?**

La réponse : les **Direct Messages NOSTR (Kind 4 / NIP-44)** sont déjà un bus de messages chiffré, authentifié, et répliqué sur les relays. Ils remplissent exactement le rôle d'une file de tâches.

***

## Le modèle conceptuel

```
Station A (léger, RPi)                    Station B (Brain-Node, GPU)
──────────────────────                    ──────────────────────────
bro_dm_daemon.sh                          bro_dm_daemon.sh
        │                                         │
        │  DM NIP-44 {"channel":"comfyui_job"}    │
        ├─────────────────────────────────────────►│
        │                                         │ flock GPU
        │                                         │ ComfyUI génère
        │                                         │ → CID IPFS
        │  DM NIP-44 {"channel":"comfyui_result"} │
        │◄─────────────────────────────────────────┤
        │                                         │
```

Chaque "channel" est un type de tâche. Le payload est un objet JSON chiffré avec NIP-44 (clé de conversation ECDH-25519). Le relay NOSTR joue le rôle de broker — les messages sont délivrés même si les deux stations ne sont pas simultanément en ligne.

***

## Les canaux gérés par bro\_dm\_daemon.sh

| Canal            | Direction         | Rôle                                                 |
| ---------------- | ----------------- | ---------------------------------------------------- |
| `plain`          | Client → BRO      | Question en langage naturel (RAG Qdrant + Ollama)    |
| `comfyui_job`    | Client → Brain    | Délégation génération vidéo/image ComfyUI            |
| `comfyui_result` | Brain → Client    | CID IPFS du résultat vidéo                           |
| `udrive`         | Nœud → Nœud       | Sync fichier IPFS vers uDRIVE distant                |
| `bro_ia`         | Roaming → Home    | Requête BRO depuis station visitée, réponse chez soi |
| `zen_like`       | Station → Station | Paiement ẐEN relayé (roaming)                        |
| `vocals`         | Client → Station  | Publication kind 1222/1244 (message vocal)           |
| `webcam`         | Client → Station  | Publication kind 21/22 (vidéo live)                  |

***

## Ce qui distingue cette approche

### Authentification gratuite

Dans RabbitMQ, on gère des credentials. Ici, l'identité de l'expéditeur est cryptographiquement prouvée par la signature Ed25519 de l'événement NOSTR. Aucun système d'authentification à maintenir.

### Chiffrement de bout en bout inclus

NIP-44 chiffre le payload avec la clé de conversation ECDH dérivée des paires de clés NOSTR des deux parties. Un observateur du relay ne voit que l'expéditeur, le destinataire, et un blob opaque.

### File d'attente distribuée et résiliente

Le relay NOSTR stocke les events non lus. Si la station B est hors ligne quand A envoie le job, elle le récupérera à sa reconnexion — comportement identique à une file persistante RabbitMQ, sans infrastructure supplémentaire.

### Sérialisation GPU via flock POSIX

Pour les jobs ComfyUI, un seul job GPU à la fois est garanti par `flock -x` sur un fichier de verrou (`~/.zen/tmp/comfyui_brain.lock`). Timeout 5 minutes. Si dépassé, le job est rejeté proprement et l'expéditeur en est notifié par DM. C'est la même garantie qu'un worker Celery avec `--concurrency=1`.

### Détection événementielle (inotifywait)

Les DMs entrants sont déposés comme fichiers JSON dans `~/.zen/tmp/bro_dm_queue/` par le filtre strfry (Kind 4). `bro_dm_daemon.sh` surveille ce répertoire via `inotifywait -e close_write` — latence de l'ordre de la milliseconde, zéro polling.

***

## Limites et compromis

* **Ordre non garanti** : les DMs NOSTR peuvent arriver dans le désordre sur le relay. Pour les tâches où l'ordre compte, un `job_id` est inclus dans le payload.
* **Pas de dead letter queue** : un job rejeté (timeout GPU) est signalé par DM mais pas réessayé automatiquement. Le client doit décider de renvoyer.
* **Dépendance relay** : si le relay est indisponible, les messages s'accumulent côté client. La liste de relays de fallback (`_RELAYS`) atténue ce risque.
* **Pas adapté aux flux haute fréquence** : NOSTR n'est pas Kafka. Ce bus est conçu pour des tâches à l'échelle humaine (génération d'image : 30–120 s), pas pour du streaming de données.

***

## Voir aussi

* [bro\_dm\_daemon.sh](https://github.com/papiche/Astroport.ONE/blob/master/IA/bro_dm_daemon.sh) — implémentation complète
* [nostr\_node\_intercom.py](https://github.com/papiche/Astroport.ONE/blob/master/IA/nostr_node_intercom.py) — couche NIP-44 Python
* [Astrosystemctl How-To](../how-to/ASTROSYSTEMCTL.md) — tunnels P2P (couche réseau complémentaire)
* [BRO RAG Personal](BRO_RAG_PERSONAL.md) — le canal `plain` en détail (RAG Qdrant)
* [NOSTR Events Reference](../reference/NOSTR_EVENTS_REFERENCE.md) — Kind 4 et canaux
