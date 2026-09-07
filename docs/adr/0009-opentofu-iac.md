# ADR 0009: OpenTofu for Infrastructure as Code

## Status
Accepted

## Context
Production infrastructure needs:
- Declarative, version-controlled infrastructure
- Multi-environment (staging, production)
- Managed services (PostgreSQL, Cloud Run, Artifact Registry, Secrets)
- No Kubernetes (per principles)
- Team can review infrastructure changes via PR
- Drift detection and remediation
- Open source, no vendor lock-in (vs Terraform BSL)

## Decision
**OpenTofu** (fork of Terraform) for production infrastructure as code.

## Architecture

```
infrastructure/
├── modules/
│   ├── postgresql/           # Cloud SQL / RDS
│   ├── cloud-run/            # Cloud Run services
│   ├── artifact-registry/    # Docker images, Maven, npm
│   ├── secrets/              # Secret Manager / Parameter Store
│   ├── vpc/                  # Network, subnets, firewall
│   ├── iam/                  # Service accounts, roles
│   ├── dns/                  # Cloud DNS, managed zones
│   └── monitoring/           # Logging, metrics, alerts
├── environments/
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── production/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── backend.tf                # Remote state (GCS + locking)
└── providers.tf              # Google Cloud / AWS provider config
```

### Key Modules

**postgresql**
- Cloud SQL (PostgreSQL 16)
- Private IP, VPC peering
- Automated backups, point-in-time recovery
- Read replicas for staging/prod
- `pgvector` extension for future AI features

**cloud-run**
- Serverpod backend service
- Flutter Web static hosting (Cloud Run + Cloud CDN)
- Worker services (if needed)
- Minimum instances = 0 (scale to zero)
- Concurrency = 80 (Serverpod default)

**artifact-registry**
- Docker registry for worker images, deployment artifacts
- Maven/npm for Dart/Flutter packages (if private)
- Retention policies, vulnerability scanning

**secrets**
- Database passwords, API keys, OAuth secrets
- Automatic rotation for database credentials
- Access via workload identity (no keys in code)

**vpc**
- Shared VPC for all environments
- Private service connect for Cloud SQL
- Egress controls for worker internet access

## Environment Strategy

| Environment | Purpose | Infrastructure |
|-------------|---------|----------------|
| `local` | Development | Docker Compose (ADR 0008) |
| `staging` | Integration testing | OpenTofu `staging/` - scaled down |
| `production` | Live traffic | OpenTofu `production/` - HA, multi-zone |

**Contracts shared**: Same `schemas/` consumed by all environments
**Infrastructure differs**: Local uses mocks; staging/prod use managed services

## State Management

- Remote state in GCS bucket with versioning
- State locking via Cloud Firestore (or GCS native locking)
- State file per environment
- No sensitive data in state (secrets referenced, not stored)

## CI/CD Integration

```yaml
# .github/workflows/infrastructure.yaml
jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: opentofu/setup-opentofu@v1
      - run: tofu fmt -check
      - run: tofu init
      - run: tofu plan -var-file=environments/${{ env.ENV }}/terraform.tfvars
  
  apply:
    needs: plan
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: ${{ env.ENV }}
    steps:
      - run: tofu apply -auto-approve -var-file=...
```

## Consequences

### Positive
- Infrastructure as code, reviewed in PR
- Same tooling locally (tofu) and in CI
- No Kubernetes complexity
- Managed services reduce operational burden
- OpenTofu = open source, community-driven

### Negative
- Learning curve for team members
- Cloud provider specific (Google Cloud modules shown)
- State file management overhead
- Drift detection requires scheduled runs

### Mitigation
- Document common patterns in `infrastructure/docs/`
- Use modules for reuse across environments
- Automated `tofu plan` on PR, `tofu apply` on merge to main
- Weekly drift detection job