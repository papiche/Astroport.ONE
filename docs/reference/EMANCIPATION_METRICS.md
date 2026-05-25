# 📊 Emancipation Metrics — Astroport vs Cloud Pro

Ce document détaille les coûts de référence utilisés pour calculer la valeur libérée par une station Astroport.ONE.

## 1. Intelligence Artificielle (Compute)
Basé sur une utilisation modérée (4h/jour de calcul GPU).
*   **Ollama (LLM)** : Équivalent instance AWS `p3.2xlarge` (V100). Coût moyen : 2.00$/heure.
    *   *Valeur Astroport* : Gratuit (auto-hébergé).
*   **ComfyUI (Images/Vidéo)** : Équivalent abonnement Midjourney "Basic" (10$/mois) ou RunPod GPU.
    *   *Valeur Astroport* : Inclus dans le Power-Score 🔥.

## 2. Stockage et Données (Storage)
*   **Nextcloud (128 Go)** : Comparé à Google One (2.99€/mois) ou iCloud.
*   **IPFS (uDrive)** : Comparé au stockage S3 + Transfert de données (Egress). S3 standard : 0.023$/Go/mois.
    *   *Valeur Astroport* : Zéro taxe sur l'Egress (P2P).

## 3. Réseau et Souveraineté (Network)
*   **Tunnels P2P (Dragon)** : Équivalent Cloudflare Argo Tunnel ou Ngrok Pro (20$/mois).
    *   *Valeur Astroport* : Natif via IPFS P2P.
*   **WireGuard Hub** : Équivalent Tailscale Business ou VPN Dédié (5$/user/mois).

## 4. Tableau de référence (Calculateur)
| Module Astroport | Service Cloud Pro | Tarif mensuel |
| :--- | :--- | :--- |
| `ollama` | AWS / Anthropic API | 40,00 € |
| `nextcloud` | Microsoft 365 / Box | 10,00 € |
| `vane` | Perplexity.ai | 20,00 € |
| `webcam/vocals` | YouTube / SoundCloud Pro | 15,00 € |
| `tunnels` | Ngrok / TeamViewer | 15,00 € |