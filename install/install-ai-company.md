Voici un guide clair pour tester et administrer votre nouvelle infrastructure **AI Company Swarm**.

### 1. Ports et Accès aux Services

Voici la liste des ports exposés sur votre machine (`localhost`) :

| Service | Port | Usage | Comment tester ? |
| :--- | :--- | :--- | :--- |
| **Paperclip** | `3100` | Interface principale (Gestion des agents et tâches) | Ouvrez `http://localhost:3100` |
| **OpenClaw** | `8000` | Passerelle et interface outils | Ouvrez `http://localhost:8000` |
| **LiteLLM Proxy** | `8001` | Proxy OpenAI (fait le pont avec Ollama) | `curl http://localhost:8001/v1/models` |
| **Qdrant DB** | `6333` | Base de données vectorielle (Mémoire) | Ouvrez le Dashboard : `http://localhost:6333/dashboard` |

---

### 2. Comment administrer l'ensemble

L'administration se fait principalement via le dossier d'installation : `~/.zen/ai-company`.

#### A. Gestion des conteneurs
Toutes les commandes doivent être lancées depuis le dossier racine : `cd ~/.zen/ai-company`.

*   **Arrêter la stack :** `docker compose -p ai-company-swarm stop`
*   **Redémarrer la stack :** `docker compose -p ai-company-swarm start`
*   **Tout supprimer (sauf les données) :** `docker compose -p ai-company-swarm down`
*   **Mettre à jour Paperclip :**
    ```bash
    cd src/paperclip && git pull && cd ../..
    docker compose -p ai-company-swarm up -d --build paperclip
    ```

#### B. Surveillance et Logs (Crucial)
Si un agent ne répond pas ou qu'une tâche échoue, vérifiez les logs en temps réel :

*   **Logs de tous les services :** `docker compose -p ai-company-swarm logs -f`
*   **Logs d'un service spécifique (ex: Paperclip) :** `docker compose -p ai-company-swarm logs -f paperclip`
*   **Vérifier la santé des conteneurs :** `docker ps` (ils doivent tous afficher `Up` ou `healthy`).

#### C. Gestion des Secrets et Clés API
Toutes les clés (mot de passe Postgres, clé maître LiteLLM, token OpenClaw) sont stockées dans le fichier caché `.env` :

```bash
cat ~/.zen/ai-company/.env
```
Si vous modifiez ce fichier, vous devez recréer les conteneurs : `docker compose -p ai-company-swarm up -d`.

#### D. Administration de LiteLLM (Gestion des modèles)
LiteLLM est le cerveau de la communication. Si vous voulez ajouter un nouveau modèle (ex: `mistral` ou `llama3`) :
1.  Téléchargez le modèle sur votre hôte : `ollama pull mistral`
2.  Éditez `litellm-config.yaml` dans `~/.zen/ai-company/`.
3.  Ajoutez le modèle dans la liste `model_list`.
4.  Redémarrez le proxy : `docker compose -p ai-company-swarm restart llm-proxy`.

#### E. Maintenance de la base de données
Les données de Paperclip (Postgres) et de Qdrant (Vecteurs) sont persistantes grâce aux volumes Docker. Elles survivent aux redémarrages.
*   **Données Postgres :** Stockées dans le volume `ai-company-swarm_postgres_data`.
*   **Données Qdrant :** Stockées dans le volume `ai-company-swarm_qdrant_storage`.

### 3. Premier réflexe en cas de problème

Si l'interface web de **Paperclip** s'ouvre mais que rien ne se passe :
1.  **Vérifiez Ollama :** `curl http://localhost:11434/api/tags`. Si ça échoue, Ollama n'écoute pas sur le bon port ou n'est pas démarré.
2.  **Vérifiez le binaire Agent :** Si vous voyez l'erreur `Command not found: agent`, relancez manuellement :
    ```bash
    docker exec -u root ai-company-swarm-paperclip-1 npm install -g @paperclipai/agent
    ```
3.  **Ré-initialisez si besoin :** Si la DB est corrompue au départ, vous pouvez forcer un reset (attention, perd les données) :
    ```bash
    docker exec -it ai-company-swarm-paperclip-1 pnpm paperclipai onboard
    ```