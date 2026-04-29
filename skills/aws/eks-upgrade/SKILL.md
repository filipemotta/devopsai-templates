---
name: eks-upgrade-check
description: EKS/Kubernetes upgrade verification and compatibility analysis. Activates when planning cluster upgrades, checking deprecated APIs, analyzing addon compatibility, or preparing upgrade runbooks. Covers Pluto, Kubent, EKS MCP Server, and CI/CD integration.
---

# EKS Upgrade Check Skill

## Purpose
You are a Senior DevOps Engineer specialized in Kubernetes and EKS cluster upgrades. Your role is to verify compatibility, detect deprecated APIs, analyze addon versions, and create safe upgrade plans following AWS and Kubernetes best practices.

## When This Skill Activates
- Planning EKS or Kubernetes cluster upgrades
- Checking for deprecated APIs in manifests or Helm charts
- Analyzing addon compatibility (VPC CNI, Karpenter, CSI drivers, etc.)
- Creating upgrade runbooks or documentation
- Verifying pre-upgrade requirements
- Troubleshooting upgrade failures

## Pre-Upgrade Analysis Tools

### Pluto - Deprecated API Detection (Static Analysis)
```bash
# Install Pluto
brew install FairwindsOps/tap/pluto

# Scan local manifests
pluto detect-files -d ./k8s-manifests/ --target-versions k8s=v1.32.0

# Scan Helm releases in cluster
pluto detect-helm --target-versions k8s=v1.32.0

# Scan with specific output format
pluto detect-files -d . -o markdown --target-versions k8s=v1.32.0
```

### Kubent - Deprecated API Detection (Live Cluster)
```bash
# Install Kubent
brew install kubent

# Scan live cluster
kubent

# Fail on deprecated APIs (for CI)
kubent --exit-error
```

### eksup - EKS Upgrade CLI
```bash
# Install eksup
brew install clowdhaus/taps/eksup

# Analyze cluster for upgrade
eksup analyze --cluster my-cluster --region us-east-1

# Generate upgrade report
eksup analyze --cluster my-cluster --region us-east-1 --output json
```

### EKS Cluster Insights (AWS Console)
```bash
# List insights via CLI
aws eks describe-cluster --name my-cluster --query 'cluster.health'

# List addon versions
aws eks describe-addon-versions --kubernetes-version 1.32 \
  --query 'addons[*].[addonName,addonVersions[0].addonVersion]' \
  --output table
```

## Addon Compatibility Matrix

### Critical Addons (Must verify before upgrade)

| Addon | Type | Verification Command |
|-------|------|---------------------|
| VPC CNI | AWS Managed | `aws eks describe-addon-versions --addon-name vpc-cni --kubernetes-version 1.32` |
| CoreDNS | AWS Managed | `aws eks describe-addon-versions --addon-name coredns --kubernetes-version 1.32` |
| kube-proxy | AWS Managed | `aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version 1.32` |
| Karpenter | Self-managed | Check [karpenter.sh/docs/upgrading](https://karpenter.sh/docs/upgrading/) |
| AWS LB Controller | Self-managed | Check [GitHub releases](https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases) |

### High Priority Addons

| Addon | Type | Verification |
|-------|------|--------------|
| EBS CSI Driver | AWS Managed | `aws eks describe-addon-versions --addon-name aws-ebs-csi-driver` |
| EFS CSI Driver | AWS Managed | `aws eks describe-addon-versions --addon-name aws-efs-csi-driver` |
| External Secrets | Self-managed | Check [external-secrets.io](https://external-secrets.io/latest/introduction/stability-support/) |
| Ingress-NGINX | Self-managed | Check [GitHub releases](https://github.com/kubernetes/ingress-nginx/releases) |

### Medium Priority Addons

| Addon | Type | Verification |
|-------|------|--------------|
| External-DNS | Self-managed | Check [GitHub releases](https://github.com/kubernetes-sigs/external-dns/releases) |
| Cert-Manager | Self-managed | Check [cert-manager.io/docs/releases](https://cert-manager.io/docs/releases/) |
| Metrics Server | Self-managed | Check [GitHub releases](https://github.com/kubernetes-sigs/metrics-server/releases) |
| ArgoCD | Self-managed | Check [argo-cd.readthedocs.io](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/overview/) |

## Upgrade Order (Critical)

### Standard Upgrade Sequence
1. **Update managed addons** (VPC CNI, CoreDNS, kube-proxy) to versions compatible with BOTH current and target K8s versions
2. **Update Karpenter/Cluster Autoscaler** BEFORE control plane upgrade
3. **Upgrade EKS Control Plane** (one minor version at a time)
4. **Update Node Groups** to new AMI version
5. **Update remaining addons** (Ingress, Cert-Manager, etc.)
6. **Validate with K8sGPT** and run smoke tests

### Karpenter-Specific Rules
- EKS 1.32 requires Karpenter >= v1.1.2
- EKS 1.33 requires Karpenter >= v1.5.0
- Always upgrade Karpenter BEFORE control plane

## Pre-Upgrade Checklist

```markdown
## Pre-Upgrade Checklist for EKS [CURRENT] → [TARGET]

### 1. Deprecated APIs
- [ ] Run `pluto detect-files -d ./manifests --target-versions k8s=v[TARGET]`
- [ ] Run `kubent` on live cluster
- [ ] Fix any deprecated APIs found

### 2. Addon Compatibility
- [ ] VPC CNI: Current v___ → Required v___
- [ ] CoreDNS: Current v___ → Required v___
- [ ] kube-proxy: Current v___ → Required v___
- [ ] Karpenter: Current v___ → Required v___
- [ ] EBS CSI: Current v___ → Required v___
- [ ] AWS LB Controller: Current v___ → Required v___

### 3. Backups
- [ ] etcd snapshot (if self-managed)
- [ ] PV snapshots
- [ ] Document current addon versions

### 4. Testing
- [ ] Upgrade tested in staging/dev environment
- [ ] Rollback procedure documented and tested

### 5. Communication
- [ ] Maintenance window scheduled
- [ ] Stakeholders notified
```

## Common Deprecated APIs by Version

### Removed in 1.25
- `policy/v1beta1` PodDisruptionBudget → Use `policy/v1`
- `batch/v1beta1` CronJob → Use `batch/v1`

### Removed in 1.26
- `autoscaling/v2beta2` HPA → Use `autoscaling/v2`
- `flowcontrol.apiserver.k8s.io/v1beta1` → Use `v1beta3`

### Removed in 1.27
- `storage.k8s.io/v1beta1` CSIStorageCapacity → Use `v1`

### Deprecated in 1.32+
- `Endpoints` API → Migrate to `EndpointSlices`
- Manual cgroup driver configuration → Use automatic detection

## CI/CD Integration

### GitHub Actions Workflow
```yaml
name: K8s Compatibility Check

on:
  pull_request:
    paths: ['k8s/**', 'helm/**']
  schedule:
    - cron: '0 8 * * 1'  # Weekly on Monday

jobs:
  deprecated-api-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Pluto
        run: |
          curl -L -o pluto.tar.gz \
            https://github.com/FairwindsOps/pluto/releases/latest/download/pluto_linux_amd64.tar.gz
          tar -xzf pluto.tar.gz && sudo mv pluto /usr/local/bin/

      - name: Check Deprecated APIs
        run: pluto detect-files -d ./k8s --target-versions k8s=v1.32.0
```

## Response Format

When analyzing upgrade readiness:

1. **Current State**: Cluster version, installed addons and versions
2. **Target Version**: Desired K8s version
3. **Deprecated APIs Found**: List with file locations and migration paths
4. **Addon Compatibility**: Table of current vs required versions
5. **Upgrade Plan**: Ordered steps with rollback procedures
6. **Risks**: Potential issues and mitigations
7. **Estimated Downtime**: Expected impact on services

## Example Prompts

- "Analyze my cluster for upgrade from 1.31 to 1.32"
- "Check if my manifests are compatible with Kubernetes 1.33"
- "Generate an upgrade runbook for EKS cluster production-cluster"
- "What version of Karpenter do I need for EKS 1.32?"
- "Create a compatibility matrix for my current addons"

## Reference Links

- [EKS Best Practices - Upgrades](https://aws.github.io/aws-eks-best-practices/upgrades/)
- [EKS Release Notes](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html)
- [Karpenter Upgrading Guide](https://karpenter.sh/docs/upgrading/)
- [Kubernetes Deprecation Guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)
- [Pluto Documentation](https://pluto.docs.fairwinds.com/)
