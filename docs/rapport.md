# Rapport de projet — TP DevOps

**Auteur** : Kevin Chaillot — Efrei Bachelor Ingénierie & numérique
**Date** : avril 2026
**Dépôt GitHub** : https://github.com/kevinMdf05/TP-DevOps-Kevin

---

## 1. Contexte

Une entreprise souhaite automatiser le déploiement de son application web afin de gagner du temps et éviter les erreurs humaines. L'objectif de ce TP est de mettre en place une solution complète intégrant :

- La conteneurisation d'une application multi-services
- L'orchestration locale avec Docker Compose
- Un déploiement sur une VM cloud Azure
- Un cluster Kubernetes (K3s)
- Un pipeline CI/CD entièrement automatisé (GitHub Actions)
- Une gestion rigoureuse des variables d'environnement et des secrets

---

## 2. Objectifs

| Objectif obligatoire                                | Couvert |
|-----------------------------------------------------|---------|
| Conteneuriser l'application avec Docker             | ✅      |
| Orchestrer plusieurs services avec Docker Compose   | ✅      |
| Exposer un endpoint `/health`                       | ✅      |
| Déployer sur une VM cloud                           | ✅      |
| Installer Kubernetes local (K3s) sur la VM          | ✅      |
| Déployer l'app dans Kubernetes                      | ✅      |
| Pipeline CI/CD complet (test, build, push, deploy)  | ✅      |
| Gestion des variables/secrets                       | ✅      |
| Documentation (README + rapport)                    | ✅      |
| **Bonus : Multi-stage build**                       | ✅      |

---

## 3. Choix techniques et justifications

### Application

- **Backend** : Node.js 20 + Express — léger, rapide à dockeriser, simple à tester
- **Base de données** : PostgreSQL 16 — image officielle fiable, persistance via PVC
- **Frontend** : Nginx + HTML/JS vanilla — démontre la communication inter-services, pas de build front à gérer
- **Tests** : Jest + Supertest — standard Node.js, 3 tests unitaires sur l'API

### Infrastructure

- **Cloud : Azure** — subscription Pay-As-You-Go (la subscription étudiante EFREI était désactivée)
- **VM : Standard_B2s** (2 vCPU, 4 Go RAM) en France Central — assez confortable pour K3s + 5 pods, coût environ 30€/mois
- **Kubernetes : K3s** — installation en une commande, léger (~50 Mo), parfaitement adapté à une VM unique. Alternative à Minikube plus simple pour la production.

### CI/CD

- **GitHub Actions** — intégré au repo, gratuit pour les repos publics
- **GHCR (GitHub Container Registry)** — gratuit, intégré, authentification simple via `GITHUB_TOKEN`
- **Déploiement SSH** — script `deploy.sh` exécuté sur la VM, substitue les images avec `sed` puis `kubectl apply`

### Sécurité

- Aucun secret commité dans le code
- `.env` local dans `.gitignore`
- Secrets stockés dans **GitHub Secrets**
- `Secret` Kubernetes créé à la volée par le pipeline
- Clé SSH dédiée au TP (`id_ed25519_tp`), distincte de la clé personnelle

---

## 4. Architecture finale

```
Développeur (git push main)
        │
        ▼
┌──────────────────── GitHub Actions ────────────────────┐
│  1. test   │  2. build-and-push   │  3. deploy         │
│  npm ci    │  docker build        │  ssh + kubectl     │
│  npm test  │  push GHCR           │  apply + restart   │
└───────────────────────┬────────────────────────────────┘
                        │ SSH
                        ▼
        ┌─── VM Azure Ubuntu 22.04 (B2s) ────┐
        │                                    │
        │   ┌── K3s (Kubernetes) ──┐         │
        │   │                      │         │
        │   │  [frontend × 2]      │         │
        │   │      ↓ /api          │         │
        │   │  [backend × 2]       │         │
        │   │      ↓ pg            │         │
        │   │  [postgres × 1]      │         │
        │   │                      │         │
        │   │  Service NodePort    │         │
        │   │  :30080              │         │
        │   └──────────────────────┘         │
        │                                    │
        └──── IP publique 4.212.91.15 ───────┘
                        ↕
                    Utilisateur
```

---

## 5. Étapes réalisées

### Étape 1 — Application et Dockerisation

- Création de l'API backend Node.js avec endpoints `/health`, `GET/POST /api/messages`
- Frontend HTML/JS minimal appelant l'API
- **Dockerfile backend multi-stage** (builder + runtime Alpine)
- Dockerfile frontend (Nginx custom)
- `docker-compose.yml` orchestrant les 3 services avec healthcheck Postgres

**Commandes** :
```bash
docker compose up --build -d
curl http://localhost:8080/health
# {"status":"ok","db":"up","uptime":11.2}
```

**📸 Capture à prendre** : page http://localhost:8080 avec message inséré + `docker compose ps` dans un terminal.

### Étape 2 — Tests unitaires

Tests Jest + Supertest sur l'API (3 tests) :
- `GET /health` → 200 avec `status:"ok"`
- `GET /` → 200 avec name/version
- `POST /api/messages` avec body vide → 400

```
PASS tests/health.test.js
Tests:       3 passed, 3 total
```

**📸 Capture à prendre** : sortie `npm test` avec les 3 tests verts.

### Étape 3 — Manifests Kubernetes

Arborescence `k8s/` :
- `00-namespace.yaml` — Namespace `tp-app`
- `10-secret.yaml` — placeholder (vrai secret créé par `deploy.sh`)
- `11-configmap.yaml` — valeurs non-sensibles (DB_HOST, PORT)
- `20-db.yaml` — PVC + Deployment + Service PostgreSQL avec probes `pg_isready`
- `30-backend.yaml` — Deployment 2 replicas + Service, probes HTTP sur `/health`
- `40-frontend.yaml` — Deployment 2 replicas + Service `NodePort :30080`
- `deploy.sh` — script idempotent : crée secrets, substitue images, applique, rollout restart

### Étape 4 — Pipeline CI/CD

Workflow `.github/workflows/ci-cd.yml` en 3 jobs séquentiels :

1. **test** — `npm ci` + `npm test`
2. **build-and-push** (si `main`) — Buildx + push sur GHCR (tags `:sha` et `:latest`)
3. **deploy** (si `main`) — SSH sur VM, copie des manifests, `deploy.sh`, smoke test

9 secrets GitHub configurés :
`VM_HOST`, `VM_USER`, `VM_SSH_KEY`, `GHCR_USER`, `GHCR_TOKEN`, `GHCR_EMAIL`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`.

**📸 Capture à prendre** : page Actions du repo GitHub avec les 3 jobs verts ; détail de l'étape `Smoke test` qui retourne le JSON `/health`.

### Étape 5 — Infrastructure Azure

Scripts `docs/azure-setup.sh` et `docs/vm-bootstrap.sh` :

```bash
./docs/azure-setup.sh        # crée RG, VM B2s, NSG, ouvre :22 et :30080
ssh -i ~/.ssh/id_ed25519_tp azureuser@<VM_IP> "bash ~/vm-bootstrap.sh"
```

Résultat :
- Resource group `tp-devops-rg`
- VM `tp-k3s` en France Central, IP `4.212.91.15`
- Docker 29.4.1 installé
- K3s v1.34.6 installé et démarré

**📸 Capture à prendre** : VM visible dans le portail Azure ; `kubectl get nodes` retournant `tp-k3s Ready control-plane`.

### Étape 6 — Déploiement final et vérification

Premier `git push` déclenche le pipeline de bout en bout :

```
✓ Install & Test        15s
✓ Build & Push images   56s
✓ Deploy to VM (K3s)    1m21s
```

Vérification en production :

```bash
curl http://4.212.91.15:30080/health
# {"status":"ok","db":"up","uptime":70.9}

curl -X POST http://4.212.91.15:30080/api/messages \
     -H "Content-Type: application/json" \
     -d '{"content":"Message en prod depuis K3s Azure!"}'
# {"id":1,"content":"...","created_at":"2026-04-23T08:53:14.712Z"}
```

Pods K8s :

```
pod/backend-7bd74b65f6-bgbhp   1/1 Running
pod/backend-7bd74b65f6-zrfk5   1/1 Running
pod/db-c668d87bf-nkvq2         1/1 Running
pod/frontend-577fc7647-4tdm4   1/1 Running
pod/frontend-577fc7647-xkdw8   1/1 Running
```

**📸 Capture à prendre** : page http://4.212.91.15:30080 dans le navigateur avec message visible (la capture `docs/screenshots/prod.png` fournie dans le dépôt).

---

## 6. Gestion des variables et secrets (détail)

| Niveau               | Stockage                        | Contenu                           |
|----------------------|---------------------------------|-----------------------------------|
| Développeur local    | `.env` (dans `.gitignore`)      | DB_USER/PASSWORD/NAME pour compose|
| CI/CD                | GitHub Secrets                  | 9 secrets (infra + DB + GHCR)     |
| Runtime Kubernetes   | `Secret` + `ConfigMap`          | DB creds en Secret, reste en CM   |
| Registry             | `imagePullSecret ghcr-pull`     | Créé à la volée par `deploy.sh`   |

Le fichier `k8s/10-secret.yaml` ne contient qu'un placeholder commité ; le vrai Secret est recréé à chaque déploiement par `kubectl create secret ... --dry-run=client -o yaml | kubectl apply -f -` (pattern idempotent).

---

## 7. Difficultés rencontrées et solutions

### Difficulté 1 — Subscription Azure étudiante désactivée
- **Symptôme** : `ReadOnlyDisabledSubscription` lors de `az group create`
- **Cause** : crédit épuisé / subscription expirée côté EFREI
- **Solution** : bascule sur la subscription Pay-As-You-Go du même compte

### Difficulté 2 — Erreur MFA au `az login`
- **Symptôme** : `AADSTS50076: must use multi-factor authentication`
- **Cause** : politique AAD imposant le MFA sur le tenant Default Directory
- **Solution** : `az login --tenant 69096e23-de16-434e-8ee5-d26dc298868f` pour cibler explicitement le bon tenant, validation MFA dans le navigateur.

### Difficulté 3 — `npm ci` sans `package-lock.json`
- **Symptôme** : build backend échouant au premier `docker compose build`
- **Cause** : `npm ci` requiert impérativement un lockfile
- **Solution** : génération initiale via `npm install --package-lock-only` puis commit du lockfile.

### Difficulté 4 — Images GHCR privées pour K3s
- **Symptôme** : sans authentification, K3s reçoit `pull access denied`
- **Solution** : création d'un `imagePullSecret` de type `docker-registry` dans le script `deploy.sh`, alimenté par le secret `GHCR_TOKEN` (PAT avec scope `read:packages`).

---

## 8. Résultat final

✅ **Application entièrement fonctionnelle** accessible sur http://4.212.91.15:30080
✅ **Pipeline CI/CD** entièrement automatique : `git push` → déploiement en ~2 min 30
✅ **5 pods Kubernetes** en Running (1 db, 2 backend, 2 frontend)
✅ **Tests unitaires** verts, échec des tests ⇒ stop du pipeline
✅ **Aucun secret** commité, tous dans GitHub Secrets / K8s Secret
✅ **Multi-stage build** (bonus)

---

## 9. Ressources

- Dépôt GitHub : https://github.com/kevinMdf05/TP-DevOps-Kevin
- URL de l'application : http://4.212.91.15:30080
- URL du pipeline : https://github.com/kevinMdf05/TP-DevOps-Kevin/actions

---

## 10. Captures à insérer dans le rapport PDF

À regrouper dans `docs/screenshots/` avant export :

1. `local-ui.png` — navigateur localhost:8080 avec message
2. `compose-ps.png` — `docker compose ps` (3 conteneurs UP)
3. `npm-test.png` — 3 tests Jest verts
4. `git-log.png` — `git log --oneline` (commits progressifs)
5. `azure-portal.png` — VM visible dans le portail Azure
6. `k3s-nodes.png` — `kubectl get nodes` sur la VM
7. `gh-actions-success.png` — 3 jobs verts dans Actions
8. `ghcr-packages.png` — les 2 images visibles sur ghcr.io
9. `k8s-pods.png` — `kubectl -n tp-app get pods,svc`
10. `prod-ui.png` — navigateur 4.212.91.15:30080 avec message en prod
11. `prod-health.png` — `curl http://4.212.91.15:30080/health` retournant le JSON
