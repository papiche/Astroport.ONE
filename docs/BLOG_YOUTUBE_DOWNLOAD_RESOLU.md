# Copier des vidéos YouTube : un problème enfin résolu

*Article tout public — avec annexe technique*

---

## Article (tout public)

### Le problème

Vous utilisez un outil pour enregistrer des vidéos ou de la musique depuis YouTube — pour les revoir hors ligne, les archiver ou les réécouter — et d’un coup ça ne marche plus. L’outil affiche des messages du type « Signature solving failed » ou « Requested format is not available », et au mieux vous n’obtenez que des vignettes, pas la vidéo ni l’audio.

Ce n’est pas un bug de votre logiciel préféré : YouTube change régulièrement la façon dont ses pages et ses flux sont protégés. Les programmes qui permettent de télécharger (comme yt-dlp, successeur de youtube-dl) doivent donc s’adapter, en particulier en exécutant de petits programmes JavaScript pour « résoudre » des défis imposés par le site. Sans cela, plus d’accès aux vrais flux vidéo et audio.

### Ce qui bloquait chez nous

Sur notre machine, nous avions une version récente de Node.js (18) installée pour d’autres usages — par exemple faire tourner TiddlyWiki. Or les versions récentes de yt-dlp exigent **Node 20 minimum** pour cette partie JavaScript. Avec Node 18, le programme refusait silencieusement le runtime : « node (unavailable) », et les téléchargements échouaient dès qu’il fallait résoudre ces défis.

Nous ne voulions pas forcer une mise à jour de Node sur tout le système (risque pour TiddlyWiki et le reste). Il fallait une solution qui laisse Node 18 en place et qui donne à yt-dlp un autre moteur JavaScript.

### La solution : Deno à la place de Node (pour yt-dlp uniquement)

Nous avons installé **Deno**, un autre moteur JavaScript, recommandé par l’équipe yt-dlp. Deno est installé à part (par exemple dans un dossier `~/.deno`), sans remplacer Node. Résultat :

- **Node 18** reste utilisé pour TiddlyWiki et tout ce qui en dépend.
- **Deno** est utilisé uniquement par yt-dlp pour résoudre les défis YouTube.
- Les téléchargements (y compris avec cookies pour les vidéos restreintes) fonctionnent à nouveau.

En pratique : installer Deno, puis relancer une fois le script de configuration de yt-dlp. Après ça, les commandes habituelles de téléchargement refonctionnent.

### En résumé

- **Problème** : YouTube change ses protections ; yt-dlp a besoin d’un moteur JavaScript à jour (Node ≥ 20 ou Deno).
- **Notre cas** : Node 18 conservé pour d’autres logiciels → yt-dlp refusait ce runtime → plus de formats disponibles.
- **Solution** : installer Deno à côté, configurer yt-dlp pour utiliser Deno → téléchargements YouTube à nouveau possibles sans toucher à Node.

Si vous êtes dans une situation similaire (Node ancien pour d’autres usages, et yt-dlp qui ne télécharge plus), l’idée est la même : ajouter Deno pour yt-dlp et le laisser pointer vers ce runtime dans sa configuration. Les détails techniques sont dans l’annexe ci-dessous.

---

## Annexe technique

### Contexte

- **yt-dlp** : outil en ligne de commande pour télécharger vidéo/audio depuis YouTube et d’autres sites.
- **EJS (External JavaScript Scripts)** : mécanisme de yt-dlp qui exécute des scripts JavaScript (signature, défi « n », etc.) pour débloquer les URLs de flux. Sans runtime JS valide, seuls certains clients (ex. `android_vr`) renvoient des formats ; avec cookies, les clients utilisés (tv, web) exigent EJS, d’où l’échec si le runtime est refusé.
- **Référence** : [yt-dlp EJS](https://github.com/yt-dlp/yt-dlp/wiki/EJS).

### Versions et runtimes

| Runtime | Version minimale pour yt-dlp EJS | Remarque |
|--------|----------------------------------|----------|
| **Deno** | 2.0.0 | Recommandé, activé par défaut si présent. |
| **Node** | 20.0.0 | Node 18.x est **unsupported** → `node (unavailable)`. |
| Bun, QuickJS | Voir wiki EJS | Alternatifs. |

Avec Node 18, la sortie verbose contient par exemple :  
`[debug] JS runtimes: node-18.19.1 (unsupported)` et  
`[debug] [youtube] [jsc] JS Challenge Providers: ... node (unavailable)`.

### Solution retenue (Deno sans toucher à Node)

1. **Installation de Deno** (dossier utilisateur, pas système) :
   ```bash
   ~/.zen/Astroport.ONE/tools/install_deno.sh
   ```
   Installe Deno dans `$HOME/.deno/bin/deno`. Optionnel : ajouter `$HOME/.deno/bin` au `PATH` dans `~/.bashrc`.

2. **Configuration de yt-dlp** :
   ```bash
   ~/.zen/Astroport.ONE/tools/install_yt_dlp_ejs_node.sh
   ```
   Le script détecte Deno (dans le PATH ou `~/.deno/bin/deno`) et écrit dans `~/.config/yt-dlp/config` :
   - `--js-runtimes deno:/chemin/vers/deno` (ou `node:/chemin` si Node ≥ 20 et pas de Deno).
   - `--remote-components ejs:github` (téléchargement des scripts EJS depuis GitHub).
   - `--extractor-args youtube:player_client=android_vr,tv_embedded,tv,android,web` (ordre des clients YouTube).

3. **Vérification** :
   ```bash
   yt-dlp -v "https://www.youtube.com/watch?v=VIDEO_ID" 2>&1 | head -30
   ```
   Vérifier la ligne `[debug] [youtube] [jsc] JS Challenge Providers:` : `deno` ne doit plus être marqué `(unavailable)`.

### Comportement avec/sans cookies

- **Sans** `--cookies-from-browser` : le client `android_vr` peut être utilisé et fournit des formats sans EJS. Utile pour les vidéos publiques.
- **Avec** `--cookies-from-browser` : yt-dlp ignore les clients qui ne gèrent pas les cookies (dont `android_vr`). Il ne reste que des clients (tv, web) qui nécessitent EJS → sans runtime JS valide (Deno ou Node ≥ 20), « Only images are available ».

D’où l’importance d’un runtime EJS valide (Deno ou Node ≥ 20) pour un usage avec cookies (vidéos restreintes, listes, etc.).

### Fichiers et scripts (Astroport.ONE)

| Fichier | Rôle |
|--------|------|
| `tools/install_deno.sh` | Installe Deno dans `~/.deno`. |
| `tools/install_yt_dlp_ejs_node.sh` | Configure `~/.config/yt-dlp/config` : préfère Deno, sinon Node ≥ 20 ; ajoute `--remote-components ejs:github` et `player_client=...`. |
| `docs/YT_DLP_EJS.md` | Dépannage EJS (causes, debug, références). |
| `install.sh` | Appelle `install_deno.sh` puis `install_yt_dlp_ejs_node.sh` pour une installation complète. |

### Exemple de commande de téléchargement (audio MP3)

```bash
yt-dlp --cookies-from-browser firefox \
  -x --no-mtime --audio-format mp3 --embed-thumbnail --add-metadata \
  -o "/home/fred/Musique/MP3/%(autonumber)s_%(title)s.%(ext)s" \
  "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Références

- [yt-dlp EJS (wiki)](https://github.com/yt-dlp/yt-dlp/wiki/EJS)
- [yt-dlp PO Token Guide](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide) (403, GVS, etc.)
- [Deno](https://deno.com/) — [Installation](https://deno.com/manual/getting_started/installation)

---

(février 2026)
