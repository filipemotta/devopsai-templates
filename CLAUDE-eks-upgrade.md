# CLAUDE.md - EKS Upgrade Project Template

Use this template as the base for EKS/Kubernetes upgrade projects. Copy it to your project's root directory and customize as needed.

---

# CLAUDE.md - EKS Upgrade Project

## Cluster Context

- **Cluster Name**: [CLUSTER_NAME]
- **Region**: [REGION]
- **Current Version**: [CURRENT_VERSION]
- **Target Version**: [TARGET_VERSION]
- **Node Groups**: [LIST_NODE_GROUPS]
- **Account ID**: [AWS_ACCOUNT_ID]

## Installed Addons

### AWS Managed Addons
- VPC CNI: v[VERSION]
- CoreDNS: v[VERSION]
- kube-proxy: v[VERSION]
- EBS CSI Driver: v[VERSION]
- EFS CSI Driver: v[VERSION] (if applicable)

### Self-Managed Addons
- Karpenter: v[VERSION]
- Cluster Autoscaler: v[VERSION] (if applicable)
- AWS Load Balancer Controller: v[VERSION]
- External-DNS: v[VERSION]
- External-Secrets: v[VERSION]
- Cert-Manager: v[VERSION]
- Ingress-NGINX: v[VERSION]
- Metrics Server: v[VERSION]
- ArgoCD: v[VERSION] (if applicable)

## AI Rules

### Pre-Upgrade (MANDATORY)

1. **Always run deprecated API checks:**
   ```bash
   pluto detect-files -d ./manifests --target-versions k8s=v[TARGET_VERSION]
   kubent
   ```

2. **Check EKS Cluster Insights:**
   ```bash
   aws eks describe-cluster --name [CLUSTER_NAME] --query 'cluster.health'
   ```

3. **Query compatible addon versions:**
   ```bash
   aws eks describe-addon-versions --kubernetes-version [TARGET_VERSION] \
     --query 'addons[*].[addonName,addonVersions[0].addonVersion]' \
     --output table
   ```

4. **Check official release notes:**
   - EKS: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html
   - Kubernetes: https://kubernetes.io/releases/

### Upgrade Order (CRITICAL)

This order MUST be followed to avoid incompatibilities:

1. Update managed addons to versions compatible with BOTH current and target versions
2. Update Karpenter/Cluster Autoscaler BEFORE control plane
3. Upgrade EKS Control Plane (one minor version at a time)
4. Update Node Groups to new version AMI
5. Update remaining self-managed addons
6. Validate with K8sGPT and smoke tests

### Post-Upgrade Validation

Check after each step:
- [ ] All pods in Running/Ready
- [ ] DNS resolution working (CoreDNS)
- [ ] Persistent volumes accessible (CSI)
- [ ] Autoscaling working (Karpenter/HPA)
- [ ] Ingress/Load Balancers active
- [ ] Certificates valid (Cert-Manager)
- [ ] External-DNS updating records
- [ ] Secrets syncing (External-Secrets)

### Rollback

In case of failure:

1. **Control Plane**: Direct rollback not possible. Restore from backup or create new cluster
2. **Node Groups**: Recreate with previous version AMI
3. **Addons**: `helm rollback [release] [revision]` or `kubectl apply` previous version

**IMPORTANT**: Document previous versions of ALL components before upgrade

### Mandatory Backups

Before starting:
- [ ] Snapshots of all critical PVs
- [ ] Export of important configmaps and secrets
- [ ] Backup of Helm releases: `helm list -A > helm-releases-backup.txt`
- [ ] Document with all current versions

## Agent Teams - Multi-Agent EKS Upgrade Validation (Opus 4.6)

> Requires: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json`

### When to Use Agent Teams
Use Agent Teams (instead of a single agent) for EKS upgrade validation when:
- Cluster has **> 20 workloads** across multiple namespaces
- Multiple dimensions need simultaneous validation (addons + APIs + security)
- Time-critical upgrades where sequential checking is too slow

### Team Structure
- **Lead**: upgrade-coordinator (creates tasks, consolidates go/no-go decision)
- **Teammate 1**: compatibility-checker (addon versions, API compatibility)
- **Teammate 2**: workload-validator (deprecated APIs, PDBs, resource limits)
- **Teammate 3**: security-auditor (RBAC, NetworkPolicies, encryption)

### Task Dependencies
- Tasks 1, 2, 3: Run in PARALLEL (no dependencies)
- Task 4 (Consolidation): blockedBy [1, 2, 3]
- Task 5 (Final Report): blockedBy [4]

### Severity Classification
- BLOCKER: Deprecated APIs removed in target version, incompatible addon versions that will break cluster
- WARNING: Recommended updates, security improvements, non-critical version mismatches
- PASS: Compatible, properly configured

### Addon Validation Rules
- Check EVERY addon against: `aws eks describe-addon-versions --kubernetes-version TARGET_VERSION`
- For self-managed: check GitHub releases + compatibility notes
- kube-proxy version MUST match target K8s version
- Karpenter: check karpenter.sh/docs/upgrading/ compatibility

### Workload Validation Rules
- Run: `pluto detect-files -d ./manifests --target-versions k8s=vTARGET`
- Run: `kubent` (live cluster scan)
- Verify PDB exists for all Deployments with replicas > 1
- Check resource limits on ALL pods (warn if missing)
- Verify PSA labels on all namespaces

### Security Validation Rules
- Audit ClusterRoleBindings for wildcard permissions
- Check NetworkPolicy coverage > 80% of namespaces
- Verify Secrets encryption at rest (KMS)
- Check admission controller webhook response times
- Flag ServiceAccounts with non-expiring tokens

### Report Format
Final report MUST include:
1. GO / CONDITIONAL GO / NO-GO decision
2. All blockers with specific remediation steps
3. Warnings with priority ranking
4. Recommended upgrade sequence with estimated times
5. Rollback plan reference

## Useful Commands

```bash
# Check current cluster version
aws eks describe-cluster --name [CLUSTER_NAME] --query 'cluster.version'

# List addons and versions
aws eks list-addons --cluster-name [CLUSTER_NAME]
aws eks describe-addon --cluster-name [CLUSTER_NAME] --addon-name [ADDON_NAME]

# Check node groups
aws eks list-nodegroups --cluster-name [CLUSTER_NAME]

# Upgrade control plane
aws eks update-cluster-version --name [CLUSTER_NAME] --kubernetes-version [TARGET_VERSION]

# Monitor upgrade
aws eks describe-update --name [CLUSTER_NAME] --update-id [UPDATE_ID]
```

## Reference Links

- [EKS Best Practices - Upgrades](https://aws.github.io/aws-eks-best-practices/upgrades/)
- [Karpenter Upgrading](https://karpenter.sh/docs/upgrading/)
- [EKS Add-on Compatibility](https://docs.aws.amazon.com/eks/latest/userguide/addon-compat.html)
- [Kubernetes Deprecation Guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)

## Upgrade History

| Date | From | To | Owner | Notes |
|------|------|-----|-------|-------|
| [DATE] | [FROM] | [TO] | [NAME] | [NOTES] |

---

**Last updated**: [DATE]
**Next planned upgrade**: [DATE] - v[VERSION]
