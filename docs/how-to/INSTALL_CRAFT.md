# Activer ses compétences après l'installation

Interface : `UPlanet/earth/install_craft.html`

> **Pour qui ?** Ce guide s'adresse à quelqu'un qui vient de lancer `install.sh`
> et qui voit apparaître une URL en fin de terminal. Aucune connaissance de NOSTR
> ou des clés cryptographiques n'est requise pour commencer.

---

## Ce qui vient de se passer dans votre terminal

`install.sh` a fait plusieurs choses en arrière-plan :

1. Installé IPFS, le relay NOSTR (strfry) et l'API UPassport
2. Créé votre **MULTIPASS** — votre identité coopérative sur le réseau
3. Enregistré un **log de session** (tout ce que le terminal a affiché) et l'a publié sur IPFS
4. **Auto-déclaré vos compétences** sur le relay local — une ligne par skill :
   ```
   ║  ✅ bash_x1
   ║  ✅ linux-admin_x1
   ║  ✅ ipfs_x1
   ║  ✅ nostr_x1
   ║  ✅ astroport-install_x1  (x2+ : cérémonie ou 3 likes)
   ```
5. Affiché cette URL :
   ```
   http://127.0.0.1:54321/earth/install_craft.html?session_cid=QmXxx...
   ### aussi accessible sur http://127.0.0.1:8080/ipns/copylaradio.com/install_craft.html?session_cid=QmXxx...
   ```

**Ces compétences existent déjà sur votre relay.** La page `install_craft.html`
permet d'y **joindre une preuve multimédia** pour les rendre plus solides,
puis de les **co-signer** avec votre clé MULTIPASS.

---

## Étape 1 — Ouvrir la page dans votre navigateur

Copiez-collez l'URL affichée en fin de terminal dans Firefox ou Chromium.

Si l'URL ne répond pas, vérifiez que les services sont bien démarrés :
```bash
./start.sh
# ou, en Docker :
docker compose ps
```

La page affiche un spinner "Chargement de la session…" pendant 2 secondes, puis
vos skills apparaissent.

---

## Étape 2 — Connecter votre MULTIPASS

Cliquez sur **⚡ Connecter MULTIPASS** (bouton en haut à droite).

Deux options :

### Option A — Extension navigateur (recommandé)

Si vous avez **Alby**, **nos2x**, ou **Flamingo** installé dans votre navigateur,
la connexion est automatique — un pop-up demande votre accord, cliquez
simplement **Autoriser**.

Vous savez si c'est le cas parce que le bouton disparaît immédiatement et un
indicateur **🟢** s'affiche.

### Option B — Clé nsec (si pas d'extension)

Pendant l'installation, le terminal a affiché une ligne de ce type :
```
NSEC=nsec1abc...xyz
```
(elle apparaît dans le bloc "=== Votre identité NOSTR ===")

Copiez cette valeur `nsec1...` et collez-la dans le champ
"🔑 Connexion MULTIPASS". La clé reste uniquement en mémoire vive —
elle n'est jamais transmise ni stockée.

> **Où retrouver son nsec si vous ne l'avez plus ?**
> ```bash
> grep NSEC ~/.zen/game/nostr/$(cat ~/.zen/game/captain)/.secret.nostr
> ```

---

## Étape 3 — Comprendre les cartes de compétences

Chaque card représente un skill détecté lors de l'installation :

```
┌─────────────────────────────────┐
│ 🔧 Bash                     x1  │
│ Scripting bash et automatisation│
│ [En attente]                    │
│                                 │
│  Médias existants (constellation) :
│  [Preuve #1] [Preuve #2]        │
│                                 │
│  📎 Glissez un média ici        │
│     ou cliquez pour choisir     │
│                                 │
│  [⚡ Activer x1]  (grisé)       │
└─────────────────────────────────┘
```

- **x1** = folksonomy auto-proclamé — valeur de base, accessible à tous
- **x2+** = nécessite une cérémonie d'adoubement ou 3 likes de la constellation
- **Médias existants** = preuves déjà partagées par d'autres nœuds — vous pouvez
  les réutiliser directement

---

## Étape 4 — Joindre une preuve

Pour chaque skill, vous avez deux possibilités :

### Réutiliser un média de la constellation (zéro upload)

Si des "Médias existants" apparaissent sous la card, cliquez sur l'un d'eux —
il se surligne en bleu. C'est suffisant pour activer le skill.

### Uploader votre propre preuve

Cliquez sur la zone pointillée (ou glissez-déposez un fichier).
Formats acceptés : **image, vidéo, PDF, .txt, .md**.

**Que mettre comme preuve ?** Tout ce qui montre que vous avez réellement
installé et utilisé l'outil :
- Une capture d'écran de votre terminal avec le résultat de `ipfs id`
- Une photo de votre serveur physique
- Un extrait du log d'installation (`ipfs cat /ipfs/QmXxx...`)
- Un court fichier texte décrivant votre installation

L'upload va vers `/api/fileupload` (UPassport local) → publie sur IPFS → génère
un `info.json` de provenance (hash SHA-256, date, auteur).

Le badge de statut passe à **📎 QmXxx... (preuve sélectionnée)**.

---

## Étape 5 — Activer chaque skill

Dès qu'une preuve est sélectionnée (ou un média constellation choisi),
le bouton **⚡ Activer x1** devient cliquable.

Cliquez dessus. Deux events NOSTR sont publiés sur votre relay local (port 7777) :

| Kind | Contenu |
|------|---------|
| **30504** | Ressource de formation — référence le CID IPFS de votre preuve |
| **30503** | Auto-attestation folksonomy — `PERMIT_BASH_X1`, signé par votre clé |

Le badge de statut passe à **✅ x1 activé · event: abc123…**

Répétez pour chaque skill.

---

## Étape 6 — Étape suivante

Une fois au moins un skill activé, un bandeau apparaît en bas de page :

```
✅ Skills activés — Prochaine étape

[👤 minelife.html → onglet Mes Compétences]  [📊 Tableau de bord ẐEN]
```

**minelife.html** vous permet de :
- Voir vos compétences acquises
- Explorer les crafts disponibles dans la constellation
- Aspirer à de nouveaux skills (Kind 30501)
- Partager des ressources de formation (Kind 30504)

---

## Résumé visuel du flux

```
install.sh (terminal, ~30 min)
  ├─ log → IPFS → QmXxx...
  ├─ install_session.json → ~/.zen/tmp/$IPFSNODEID/
  └─ emit_skill.sh → Kind 30503 x1 sur relay (bash, linux-admin, ipfs, nostr, astroport-install)

                ↓  (URL affichée dans le terminal)

install_craft.html (navigateur, ~5 min)
  ├─ GET /api/skill/session → affiche votre session
  ├─ GET /api/skill/media/{skill} → médias constellation (Kind 30504)
  ├─ Connexion MULTIPASS (extension ou nsec)
  ├─ Upload preuve → /api/fileupload → {new_cid, info_cid}
  ├─ Publish Kind 30504 (ressource avec info.json)
  └─ Publish Kind 30503 (auto-attestation PERMIT_*_X1)

                ↓  (footer-cta)

minelife.html (navigateur, utilisation continue)
  ├─ Mes Compétences → voir, révoquer
  ├─ Explorer → crafts (Kind 30500)
  ├─ Aspirer → Kind 30501 (demande X1)
  ├─ Valider pairs → Kind 7 reaction "+"
  └─ Formation → ressources Kind 30504
```

---

## FAQ pour les nouveaux

**Q : Je ne vois pas l'URL à la fin de l'installation.**  
R : Elle n'apparaît que si IPFS tourne et que `emit_skill.sh` est disponible.
Relancez `./install.sh` ou accédez directement à
`http://astroport.$(hostname -f)/earth/install_craft.html`.

**Q : La page affiche "Impossible de charger la session".**  
R : UPassport n'est peut-être pas démarré. Vérifiez : `systemctl status upassport`
ou `docker compose logs astroport | grep 54321`.

**Q : Le relay refuse mes events (message "Relay a rejeté l'event").**  
R : Vérifiez que strfry tourne : `systemctl status strfry` (bare metal) ou
`docker compose logs astroport | grep 7777`.

**Q : Je veux tester sans mes vraies données.**  
R : Ouvrez la page sur `localhost` ou ajoutez `?demo=1` à l'URL — trois comptes
de démonstration (coucou / toto / jean) apparaissent. Ces comptes sont créés par
`./test.sh wotx2`.

**Q : À quoi sert le x2 mentionné dans l'interface ?**  
R : x1 est auto-proclamé — n'importe qui peut le faire. x2+ nécessite une
validation par la constellation : soit 3 réactions Kind 7 "+" de pairs qui
détiennent déjà ce skill en x1, soit un adoubement direct (Kind 30502) d'un pair
x1+. Cela se passe dans minelife.html, onglet "Explorer".

---

## Fichiers de référence

| Fichier | Rôle |
|---------|------|
| `UPlanet/earth/install_craft.html` | Cette interface |
| `Astroport.ONE/tools/emit_skill.sh` | Publie Kind 30503 depuis le terminal |
| `UPassport/routers/skills.py` | Endpoints `/api/skill/session` et `/api/skill/media/{skill}` |
| `Astroport.ONE/install.sh` | Appelle `emit_skill.sh` en fin d'installation |
| `Astroport.ONE/test.sh wotx2` | Crée les comptes démo coucou/toto/jean |

---

## Voir aussi

- [MINELIFE.md](MINELIFE.md) — Utiliser l'interface de crafting complète
- [reference/WOTX2_SYSTEM.md](../reference/WOTX2_SYSTEM.md) — Architecture WoTx2
- [reference/NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md) — Spec Kind 30503/30504
