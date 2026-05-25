# Convertir un NotebookLM en projet Claude Code

`git.notebook.sh` transforme un notebook [NotebookLM](https://notebooklm.google.com) en dépôt
Git prêt à l'emploi avec Claude Code : CLAUDE.md pré-rempli, commandes slash, règles par chemin,
et digest complet des sources du notebook.

Le projet est créé dans `~/.zen/workspace/notebooklm/<nom-du-projet>`.

---

## Prérequis

```bash
pip install playwright
playwright install chromium
```

---

## Usage rapide

```bash
./git.notebook.sh --url "https://notebooklm.google.com/notebook/xxxxxxxx"
```

Si votre cookie NotebookLM est déjà stocké dans UPassport (voir ci-dessous), le script
le récupère automatiquement. Sinon il ouvre la page de gestion des cookies et vous guide.

---

## Obtenir et stocker le cookie NotebookLM

NotebookLM nécessite une session Google authentifiée. Le cookie est capturé une fois
puis chiffré et stocké dans votre MULTIPASS via l'API UPassport.

### 1. Exporter le cookie depuis le navigateur

Installez l'extension **Get cookies.txt LOCALLY** (Chrome/Firefox).

1. Connectez-vous sur [notebooklm.google.com](https://notebooklm.google.com)
2. Cliquez sur l'icône de l'extension → **Export** → format Netscape
3. Sauvegardez le fichier `.txt`

### 2. Uploader le cookie dans UPassport

```
http://127.0.0.1:54321/cookie.html
```

Le cookie est chiffré avec votre clef G1 (natools), stocké sur IPFS, et référencé
dans un événement NOSTR kind 31903. À la prochaine utilisation, le script le
récupère automatiquement.

### 3. Vérifier le stockage

Le cookie apparaît dans votre profil NOSTR (`nostr_profile_viewer.html`) sous
**Cookies chiffrés** avec le domaine `notebooklm.google.com` et son âge.

---

## Passer le cookie directement (sans stockage)

```bash
# Via fichier Netscape
./git.notebook.sh \
  --url "https://notebooklm.google.com/notebook/xxx" \
  --cookie-file ~/cookies_notebooklm.txt

# Via cookies inline
./git.notebook.sh \
  --url "https://notebooklm.google.com/notebook/xxx" \
  --cookie "SID=xxx; HSID=yyy; SSID=zzz"
```

---

## Ce que le script génère

```
~/.zen/workspace/notebooklm/<nom-du-projet>/
├── CLAUDE.md                   ← mémoire persistante (stack, conventions, digest notebook)
├── README.md
├── .gitignore
├── .env.example
├── src/
├── tests/
├── docs/
│   ├── notebook_digest.md      ← résumé structuré (sources, notes, chat)
│   └── notebook_full.json      ← données brutes extraites
└── .claude/
    ├── commands/               ← /review /test /doc /task /notebook /init-feature
    └── rules/                  ← règles par chemin (api/, tests/, core/)
```

Après génération, lancez simplement :

```bash
cd ~/.zen/workspace/notebooklm/<nom-du-projet>
claude
```

Claude Code charge automatiquement le CLAUDE.md avec tout le contexte du notebook.

---

## Options complètes

| Option | Description |
|--------|-------------|
| `--url URL` | URL du notebook (ou `NOTEBOOKLM_URL`) |
| `--cookie 'K=V; …'` | Cookies inline (ou `NOTEBOOKLM_COOKIE`) |
| `--cookie-file FILE` | Fichier Netscape `.txt` ou `.json` |
| `--project-dir DIR` | Dossier destination (défaut : `~/.zen/workspace/notebooklm/<name>`) |
| `--notebook-json FILE` | Sauter l'extraction, utiliser un JSON déjà produit |
| `--non-interactive` | Aucun prompt — valeurs par défaut partout (CI/CD) |

---

## Mode CI/CD

```bash
NOTEBOOKLM_URL="https://notebooklm.google.com/notebook/xxx" \
NOTEBOOKLM_COOKIE="SID=…" \
./git.notebook.sh --non-interactive --project-dir /srv/projets/mon-projet
```

---

## Rafraîchir un projet existant

Si le notebook a évolué, relancez le script avec `--project-dir` pointant vers
le projet existant. Les fichiers `docs/notebook_digest.md` et `docs/notebook_full.json`
sont écrasés ; `CLAUDE.md` et `.claude/` sont régénérés.

```bash
./git.notebook.sh \
  --url "https://notebooklm.google.com/notebook/xxx" \
  --project-dir ~/.zen/workspace/notebooklm/mon-projet
```

---

## Dépannage

| Symptôme | Cause probable | Solution |
|----------|---------------|----------|
| `Extraction échouée` | Cookie expiré | Ré-exporter et uploader via `/cookie.html` |
| `notebooklm_playwright.py introuvable` | Playwright non installé | `pip install playwright && playwright install chromium` |
| `--url invalide` | URL ne contient pas `notebooklm.google.com` | Vérifier l'URL copiée depuis le navigateur |
| Notebook vide (0 sources) | Session non connectée | Vérifier que le cookie contient bien `SID` et `HSID` |
