# TP DevOps — Conteneurisation, Kubernetes et CI/CD

Application full-stack déployée automatiquement via GitHub Actions sur une VM Azure équipée de K3s.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VM Azure (Ubuntu 22.04)                  │
│                                                             │
│   ┌──────────────────  K3s (Kubernetes)  ─────────────────┐ │
│   │                                                       │ │
│   │   [Pod frontend]   [Pod backend x2]   [Pod postgres]  │ │
│   │    Nginx :80   →    Node/Express      PostgreSQL      │ │
│   │        ↑              :3000  ↔   DB Service           │ │
│   │        │                                              │ │
│   │    Service NodePort :30080                            │ │
│   └───────────┬───────────────────────────────────────────┘ │
└───────────────┼─────────────────────────────────────────────┘
                │
         http://<VM_IP>:30080
```

## Stack technique

| Couche          | Techno                                 |
|-----------------|----------------------------------------|
| Frontend        | Nginx + HTML/JS vanilla                |
| Backend         | Node.js 20 + Express                   |
| Base de données | PostgreSQL 16                          |
| Conteneurs      | Docker multi-stage + Docker Compose    |
| Orchestration   | Kubernetes (K3s)                       |
| Cloud           | Azure — VM Ubuntu 22.04 LTS (B1s/B2s)  |
| CI/CD           | GitHub Actions + GHCR                  |
| Secrets         | GitHub Secrets + Kubernetes Secret     |

## Fonctionnement local

Prérequis : Docker, Docker Compose.

```bash
cp .env.example .env
docker compose up --build -d
```

- Frontend : http://localhost:8080
- Health backend : http://localhost:8080/health
- API messages : `GET/POST http://localhost:8080/api/messages`

Arrêt : `docker compose down -v`

### Lancer les tests en local

```bash
cd backend
npm install
npm test
```

## Déploiement sur VM (manuel, première fois)

1. **Créer la VM Azure** (via `az cli` ou portail) : Ubuntu 22.04, B1s/B2s, ports ouverts 22 et 30080.
2. **Se connecter en SSH** et lancer :

   ```bash
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker $USER
   curl -sfL https://get.k3s.io | sh -
   sudo chmod 644 /etc/rancher/k3s/k3s.yaml
   ```

3. Le pipeline CI/CD prend le relais à chaque push sur `main`.

## Pipeline CI/CD

Chaque `git push` sur `main` déclenche :

1. **test** — `npm ci` + `npm test` (Jest)
2. **build-and-push** — Build des images Docker + push sur GHCR
3. **deploy** — SSH sur la VM, copie des manifests, `kubectl apply`, `rollout restart`

En cas d'échec d'un test, les étapes suivantes ne s'exécutent pas.

## Secrets GitHub à configurer

| Secret          | Rôle                                               |
|-----------------|----------------------------------------------------|
| `VM_HOST`       | IP publique de la VM                               |
| `VM_USER`       | Utilisateur SSH (ex: `azureuser`)                  |
| `VM_SSH_KEY`    | Clé privée SSH (contenu de `id_ed25519_tp`)        |
| `GHCR_USER`     | Nom d'utilisateur GitHub                           |
| `GHCR_TOKEN`    | PAT avec scope `read:packages`                     |
| `GHCR_EMAIL`    | Email GitHub                                       |
| `DB_USER`       | Utilisateur PostgreSQL                             |
| `DB_PASSWORD`   | Mot de passe PostgreSQL                            |
| `DB_NAME`       | Nom de la base                                     |

## Gestion des variables et secrets

- `.env` local **jamais commité** (dans `.gitignore`)
- `k8s/10-secret.yaml` : placeholder — le vrai Secret est créé à la volée par `deploy.sh` avec les valeurs issues de GitHub Secrets
- `ConfigMap` pour les valeurs non-sensibles (DB_HOST, PORT…)
- `imagePullSecret ghcr-pull` créé dynamiquement pour que K3s puisse tirer les images privées de GHCR

## Structure du dépôt

```
.
├── backend/              # API Node.js + tests Jest
│   ├── src/
│   ├── tests/
│   ├── Dockerfile        # multi-stage
│   └── package.json
├── frontend/             # Nginx + HTML
│   ├── html/
│   ├── nginx/
│   └── Dockerfile
├── k8s/                  # Manifests Kubernetes + deploy.sh
├── .github/workflows/    # Pipeline GitHub Actions
├── docker-compose.yml
├── .env.example
└── README.md
```

## Bonus : Terraform (Infrastructure-as-Code)

Dossier `terraform/` : provisioning reproductible de la VM Azure.

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

## Bonus : Monitoring (Prometheus + Grafana)

La stack `kube-prometheus-stack` est déployée via Helm dans le namespace `monitoring`.
Le backend Node.js est instrumenté avec `prom-client` et expose `/metrics`.
Un `ServiceMonitor` indique à Prometheus de scraper le backend toutes les 15 s.

- Grafana : http://<VM_IP>:30090 (admin / admin)
- Dashboards K8s pré-intégrés (Node, Pods, API Server, etc.)
- Alertmanager embarqué

### Installation (une seule fois sur la VM)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f k8s/monitoring-values.yaml --wait
```

## Difficultés rencontrées

Voir le rapport de projet (`docs/rapport.md`).

## Auteur

**Kevin Chaillot** — Efrei Bachelor Ingénierie & numérique
TP réalisé dans le cadre d'un module DevOps (avril 2026).

