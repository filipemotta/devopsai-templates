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

### Rollback (5 layers)

"Rollback is a revert" is a slogan. A Git revert restores declared intent; each layer converges back through its own path:

1. **Git**: revert the commit that bumped the version variables (AMI pin, addon versions, cluster version). Restores intent only; nothing has converged yet
2. **Nodes**: a versioned AMI alias CANNOT take kubelets back to N-1 while the control plane is on N (the alias resolves against the current control plane version). Use an EC2NodeClass with the explicit N-1 AMI ID (record it during preflight), or a blue/green NodePool kept on the previous version
3. **Addons**: explicit downgrade per compatibility matrix (`aws eks update-addon --resolve-conflicts PRESERVE`); Git does not perform this
4. **Control Plane**: EKS supports native Kubernetes version rollback to the previous minor version **within 7 days** of the upgrade, one minor at a time. EKS evaluates rollback readiness insights first (API compatibility, version skew, addon compatibility, cluster health); the revert preserves etcd data, workloads and PVs. While nodes are still on N (bake state), this is the cheapest rollback of all: nothing else moves
5. **CRDs and stored objects**: the least reversible layer. Once controllers wrote new schemas into etcd, going back is a migration question, not a Git question. Read downgrade notes BEFORE upgrading

**IMPORTANT**: Document previous versions of ALL components (including the exact AMI ID) before upgrade, and rehearse the rollback at least once in a non-critical environment. A rollback that has never run is a document, not a capability.

## Karpenter Drift as the Node Upgrade Engine

If nodes are Karpenter-managed, node upgrades happen by **replacement via drift**, not mutation:

- **The versioned alias trap**: an alias like `al2023@vYYYYMMDD` pins the AMI *release*, NOT the Kubernetes version. It re-resolves against the control plane version, so the control plane hop itself marks every node Drifted and starts the rotation with zero manifest changes. Decide the gate BEFORE the hop:
  - Freeze the rotation: budget `{reasons: [Drifted], nodes: "0"}`, lift it as a separate deliberate step
  - Or pin by explicit AMI ID (immune to cluster version changes)
  - Or stage a second NodePool (blue/green)
  - Or accept the automatic rotation and schedule the hop inside the maintenance window
- **Budget gotchas (all three bite in production)**:
  1. Budget schedules run in UTC (no timezone support): convert explicitly and comment the local window in the manifest
  2. Defining ANY budget removes the implicit 10% default from reasons you do not name: give consolidation (`Underutilized`, `Empty`) its own explicit line
  3. Percentages round UP: a 3-node pool with "10%" still allows 1 node (33%). Combine with a numeric budget when an absolute ceiling matters
- **Expiration is forceful**: `expireAfter` is NOT paced by disruption budgets and does not wait for replacement capacity. `terminationGracePeriod` bounds any drain (drift included) and is required to keep PDB-blocked expired nodes from sitting half-drained forever. The pair's sum is the worst-case node lifetime
- **Bootstrap island**: keep the Karpenter controller on a small managed node group or Fargate profile, never exclusively on Karpenter-provisioned capacity

## Fleet Scale (multi-cluster)

- Ship **waves**, not clusters: canaries → entire dev fleet → staging → production in batches by criticality tier, go/no-go review between batches
- Two reconcilers read the same repo: Terraform (or equivalent) for control plane + managed addons, Argo CD for in-cluster resources (NodePools, EC2NodeClasses, controllers). The control plane version is not a Kubernetes API resource
- Never let the fleet spread across more than 2 minor versions
- The pipeline enforces sequencing, not people
- The 7-day native rollback window is the bake timer: let each wave soak inside it before promoting the next

### Mandatory Backups

Before starting:
- [ ] Snapshots of all critical PVs
- [ ] Export of important configmaps and secrets
- [ ] Backup of Helm releases: `helm list -A > helm-releases-backup.txt`
- [ ] Document with all current versions

## Agent Teams - Multi-Agent EKS Upgrade Validation (Opus 4.6+, recommended Opus 4.7 with xhigh effort)

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
- [EKS Cluster Version Rollback Best Practices](https://docs.aws.amazon.com/eks/latest/best-practices/rollback-cluster-upgrades.html)
- [Karpenter Upgrading](https://karpenter.sh/docs/upgrading/)
- [Karpenter Managing AMIs](https://karpenter.sh/docs/tasks/managing-amis/)
- [EKS Add-on Compatibility](https://docs.aws.amazon.com/eks/latest/userguide/addon-compat.html)
- [Kubernetes Deprecation Guide](https://kubernetes.io/docs/reference/using-api/deprecation-guide/)

## Related Templates in This Repository

- `skills/eks-upgrade-preflight/` — consolidated preflight (pluto + kubent + insights + matrices + drift exposure)
- `skills/eks-upgrade-rollback-drill/` — guided 5-layer rollback rehearsal
- `subagents/eks-upgrade-validator.md` — bake-state and wave validation gate
- `poc/eks-karpenter-upgrade/` — reproducible single-cluster POC (Terraform + manifests + 8 runbook scripts)

## Upgrade History

| Date | From | To | Owner | Notes |
|------|------|-----|-------|-------|
| [DATE] | [FROM] | [TO] | [NAME] | [NOTES] |

---

**Last updated**: 2026-08-05
**Next planned upgrade**: [DATE] - v[VERSION]
