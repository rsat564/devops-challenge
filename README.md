# CloudOps DevOps Challenge - Azure Infrastructure

Production-ready Azure infrastructure using Terraform with modular design, multi-environment support, and automated CI/CD pipelines.

## Project Structure

```
├── modules/
│   ├── vnet/              # Network module (VNet, Subnets, NSGs, Routes)
│   ├── vm/                # Compute module (Linux VM, Disks, Extensions)
│   └── storage/           # Storage module (Account, Containers, Lifecycle)
├── infrastructure/
│   ├── main.tf            # Root module composing all modules
│   ├── variables.tf       # Input variables
│   ├── outputs.tf         # Output values
│   ├── versions.tf        # Provider & backend config
│   ├── providers.tf       # Provider configuration
│   └── environments/      # Per-environment configs
│       ├── dev-eastus.tfvars / dev-eastus.backend.hcl
│       ├── test-eastus2.tfvars / test-eastus2.backend.hcl
│       └── prod-westeurope.tfvars / prod-westeurope.backend.hcl
├── scripts/
│   ├── setup-backend.sh   # One-time state backend setup (bash)
│   └── setup-backend.ps1  # One-time state backend setup (PowerShell)
├── .github/workflows/
│   ├── terraform-ci.yml   # CI: format, validate, lint, security, tests
│   ├── terraform-deploy.yml  # Deploy: plan/apply/destroy per environment
│   └── promote.yml        # Environment promotion (dev→test→prod)
└── docs/
    ├── ARCHITECTURE.md
    ├── DEPLOYMENT.md
    ├── MODULE-USAGE.md
    ├── ENVIRONMENT-PROMOTION.md
    └── STATE-MANAGEMENT.md
```

## Quick Start

```bash
# 1. Setup state backend (one-time)
az login
./scripts/setup-backend.sh

# 2. Initialize & deploy to dev
cd infrastructure
terraform init -backend-config=environments/dev-eastus.backend.hcl
terraform plan -var-file=environments/dev-eastus.tfvars
terraform apply -var-file=environments/dev-eastus.tfvars
```

## Key Features

- **Modular Design** — Reusable, independently testable modules with native Terraform tests
- **Multi-Environment** — Separate configs for dev/test/prod with isolated state files
- **Security** — Customer-managed keys, Trusted Launch, NSG deny-all, RBAC-only storage
- **HA & Scalability** — Availability Zones, zone-redundant LB, ZRS/RAGZRS storage
- **CI/CD** — GitHub Actions with Service Principal auth, approval gates, security scanning
- **State Management** — Azure Storage backend with versioning, locking, and recovery

## State Backend

| Setting | Value |
|---------|-------|
| Resource Group | `rg-cloudops-tfstate` |
| Storage Account | `stcloudopstfstate` |
| Container | `tfstate` |
| State Keys | `dev-eastus/terraform.tfstate`, `test-eastus2/terraform.tfstate`, `prod-westeurope/terraform.tfstate` |

See [docs/STATE-MANAGEMENT.md](docs/STATE-MANAGEMENT.md) for best practices for large teams.

## Environments

| Environment | Region | CIDR | Deployment |
|-------------|--------|------|------------|
| dev | East US | 10.10.0.0/16 | Auto on push to main |
| test | East US 2 | 10.20.0.0/16 | Manual promotion + approval |
| prod | West Europe | 10.30.0.0/16 | Manual promotion + approval |

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — System design & security controls
- [Deployment](docs/DEPLOYMENT.md) — Setup & deployment instructions
- [Module Usage](docs/MODULE-USAGE.md) — How to use each module
- [Environment Promotion](docs/ENVIRONMENT-PROMOTION.md) — Promotion workflow
- [State Management](docs/STATE-MANAGEMENT.md) — Backend setup & team best practices
- [Plan Output](docs/PLAN-OUTPUT.md) — Terraform plan output for dev environment
