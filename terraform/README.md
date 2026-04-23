# Terraform — Provisioning VM Azure

Infrastructure-as-Code équivalent au script `docs/azure-setup.sh`.

## Prérequis

- Terraform >= 1.5
- `az login` déjà fait, subscription active sélectionnée
- Clé SSH dédiée générée : `~/.ssh/id_ed25519_tp` (sinon adapter `variables.tf`)

## Utilisation

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

Les `outputs` affichent l'IP publique, la commande SSH et les URLs de l'application et Grafana.

Pour détruire toute l'infra :

```bash
terraform destroy -auto-approve
```

## Ce qui est provisionné

| Ressource                   | Rôle                                      |
|-----------------------------|-------------------------------------------|
| Resource group              | Conteneur Azure                           |
| Virtual Network + Subnet    | Réseau privé                              |
| Public IP (Static, Standard)| IP publique fixe                          |
| Network Security Group      | Firewall (SSH 22, app 30080, grafana 30090)|
| Network Interface           | Carte réseau liée à la VM                 |
| Linux VM Ubuntu 22.04 (B2s) | Machine K3s                               |

Après `terraform apply`, lancer ensuite `docs/vm-bootstrap.sh` sur la VM pour installer Docker + K3s (pas dans Terraform pour garder une séparation claire IaC / configuration).
