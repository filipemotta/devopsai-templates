# CLAUDE.md - Complete DevOps Template

## Project Context - [Project Name]

### Architecture Overview
- Type: Microservices (15 services)
- Infrastructure: Kubernetes 1.28 on AWS EKS
- IaC: Terraform 1.6+ (remote state on S3 + DynamoDB)
- CI/CD: GitHub Actions
- Observability: Prometheus, Grafana, ELK Stack

### Repository Structure
```
project/
├── terraform/          # Infrastructure as Code
│   ├── modules/       # Reusable modules
│   └── environments/  # dev, staging, prod
├── k8s/               # Kubernetes manifests
│   ├── base/
│   └── overlays/
├── .github/workflows/ # CI/CD pipelines
└── .claude/           # AI configuration
    ├── agents/        # Specialized sub-agents
    └── settings.json  # Permissions
```

### Key Technical Decisions

#### Infrastructure
- Always use remote backend (S3 + DynamoDB for state locking)
- Never commit `.tfstate` files
- Modules must be versioned (git tags)
- Use workspaces for environments (dev, staging, prod)

#### Kubernetes
Security:
- Always set `runAsNonRoot: true`
- Always define resource requests/limits
- Use Sealed Secrets (never plaintext)
- NetworkPolicies are mandatory for all services

Networking:
- Ingress only via AWS ALB Controller
- Services use ClusterIP (not LoadBalancer)
- External access only via Ingress

#### Security Standards
Secrets Management:
- Use AWS Secrets Manager or Sealed Secrets
- Rotate credentials every 90 days
- Never commit secrets to Git (git-secrets hook enabled)

IAM:
- Least privilege principle
- Use IAM Roles for Service Accounts (IRSA)
- No long-lived access keys

Security Groups:
- NEVER expose 0.0.0.0/0 except ports 80/443
- SSH (22) only from VPN CIDR: 10.0.0.0/8
- Database ports (3306, 5432) only from app Security Groups

#### Compliance
Tagging (every resource must have):
- `Environment` (dev/staging/prod)
- `Team` (platform/backend/frontend)
- `CostCenter` (for FinOps tracking)

Retention:
- RDS snapshots: 7 years (compliance requirement)
- Logs: 90 days in CloudWatch, 2 years in S3

### Sub-Agents Available
- k8s-troubleshoot: Kubernetes diagnostics and troubleshooting
- terraform-reviewer: IaC security & best practices
- ci-security-analyst: CI/CD vulnerability analysis
- incident-analyzer: Production incident investigation
- security-auditor: Security audit and CVE triage

### Workflows & Commands
See `.claude/commands/` for reusable slash commands.

### DO's and DON'Ts

#### DO:
- Run `terraform plan` before every apply
- Use `--dry-run` for kubectl commands
- Tag all AWS resources
- Document breaking changes in PRs
- Run security scans before merging

#### DON'T:
- Never run `terraform destroy` in prod without approval
- Never commit secrets (git-secrets will block)
- Never deploy on Fridays after 3 PM
- Never skip PR reviews for infra changes
- Never modify production manually (always via IaC)

### Team Contacts
- Platform Team: @platform-team (Slack)
- Security: @security-team
- On-call: See PagerDuty schedule
