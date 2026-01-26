# CLAUDE.md - Template DevOps Project

## Project Overview
- **Name**: [Nome do Projeto]
- **Type**: [Microservices/Monolith/Serverless]
- **Environment**: [Development/Staging/Production]

## Architecture
- **Infrastructure**: Kubernetes [version] on [AWS EKS/GCP GKE/Azure AKS]
- **IaC**: Terraform [version] (remote state on [S3/GCS/Azure Blob])
- **CI/CD**: [GitHub Actions/GitLab CI/Jenkins/ArgoCD]
- **Container Registry**: [ECR/GCR/ACR/DockerHub]

## Key Standards

### Kubernetes
- Always set resource requests/limits
- Never commit secrets (use Sealed Secrets or External Secrets)
- Use PodDisruptionBudgets for critical workloads
- Implement health checks (liveness/readiness probes)

### Terraform
- Use remote state with locking
- Separate environments via workspaces or directories
- Tag all resources for cost allocation
- Never hardcode credentials

### Security
- Security Groups: NEVER expose 0.0.0.0/0 except ports 80/443
- Use IAM roles instead of access keys
- Enable encryption at rest and in transit
- Follow principle of least privilege

## Repository Structure
```
project/
├── terraform/          # Infrastructure as Code
│   ├── modules/       # Reusable modules
│   ├── environments/  # Per-environment configs
│   └── backend.tf     # State configuration
├── k8s/               # Kubernetes manifests
│   ├── base/         # Kustomize base
│   └── overlays/     # Environment overlays
├── .github/           # CI/CD workflows
└── .claude/           # AI configuration
```

## Team Contacts
- Platform Team: @platform-team (Slack)
- Security Team: @security-team (Slack)
- On-call: See PagerDuty schedule

## Common Commands
```bash
# Terraform
terraform plan -out=plan.tfplan
terraform apply plan.tfplan

# Kubernetes
kubectl get pods -n [namespace]
kubectl logs -f [pod-name] -n [namespace]

# Docker
docker build -t [image:tag] .
docker push [image:tag]
```

## Known Issues / Gotchas
- [Document any project-specific quirks here]
