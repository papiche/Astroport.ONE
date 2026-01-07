# Astroport.ONE - TODO Principal

**Projet** : N² Constellation Protocol (Conway's Angel Game)  
**Objectif** : Coordination décentralisée sans autorité centrale

---

## 🎯 Priorités Actuelles

### Haute Priorité 🔴

- [ ] **Système de mémoire N²** - Stockage NOSTR (kind 31910) des décisions
  - [x] Implémentation `todo.sh` avec UX interactive
  - [ ] Test avec clé `uplanet.G1.nostr`
  - [ ] Synchronisation inter-stations

### Moyenne Priorité 🟡

- [ ] **Open Collective Integration** - Publication automatique des rapports
  - [ ] Obtenir Personal Token pour `monnaie-libre`
  - [ ] Tester `./todo.sh --day`

- [ ] **Économie Ẑen** - Parité 1Ẑ = 1€
  - [ ] Vérifier flux PAF burn (4 semaines)
  - [ ] Intégration Open Collective pour conversion

---

## 🚀 Roadmap Intégrations (Développement Décentralisé)

### Phase 1 : Radicle (Forge P2P)

> **Objectif** : Remplacer GitHub/GitLab par une forge souveraine

- [ ] Installer Radicle sur une station pilote
- [ ] Migrer Astroport.ONE vers `rad://` 
- [ ] Intégrer COBs (Issues/Patches) avec mémoire N²
- [ ] Documenter le workflow décentralisé

**Ressources** : https://radicle.xyz/

### Phase 2 : NextGraph (Documents CRDT)

> **Objectif** : Collaboration temps réel sur documents UPlanet

- [ ] Évaluer SDK NextGraph (alpha)
- [ ] Prototype : UMAP documents avec CRDTs
- [ ] Requêtes SPARQL sur données géographiques
- [ ] Intégration avec DID (kind 30800)

**Ressources** : https://nextgraph.org/

---

## 📋 Systèmes Clés

| Système | État | Fichiers |
|---------|------|----------|
| RUNTIME (N² scheduler) | ✅ Actif | `20h12.process.sh` |
| NOSTR (NIP-101) | ✅ Actif | `tools/nostr_*.py` |
| Économie Ẑen | ✅ Actif | `RUNTIME/ZEN.*.sh` |
| DID/ORE | 🟡 En cours | `tools/did_*.sh` |
| todo.sh (Mémoire N²) | ✅ Nouveau | `todo.sh` |

---

## 📚 Documentation

- [NIP-101 N² Constellation Sync](../nostr-nips/101-n2-constellation-sync-extension.md)
- [NIP-101 Economic Health](../nostr-nips/101-economic-health-extension.md)
- [Architecture UPlanet](../nostr-nips/UPLANET_EXTENSIONS.md)

---

**Note** : Ce fichier est mis à jour manuellement. Utilisez `./todo.sh` pour générer des rapports automatiques basés sur les modifications Git.

*Dernière mise à jour : 2026-01-07*
