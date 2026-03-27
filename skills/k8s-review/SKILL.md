---
name: k8s-review
description: Review Kubernetes manifests for security, reliability and best practices before deployment. Scores manifests across three dimensions and returns prioritized findings with specific YAML fixes.
---

# /k8s-review

## Purpose
Perform an automated code review of Kubernetes manifests, checking security hardening, reliability patterns, and operational best practices. Returns scored results with prioritized, actionable fixes.

## Data Collection

1. Find all `.yaml` / `.yml` files with Kubernetes manifests in the project
2. Catalog resources found: Deployments, StatefulSets, DaemonSets, Services, Ingresses, ConfigMaps, Secrets, RBAC, NetworkPolicies, PDBs, HPAs
3. If `kubectl` is available: compare manifests with live cluster state to detect drift

## Security Checklist

- [ ] Containers running as non-root (`runAsNonRoot: true`)
- [ ] Read-only root filesystem (`readOnlyRootFilesystem: true`)
- [ ] No privileged containers (`privileged: false`)
- [ ] `allowPrivilegeEscalation: false` on all containers
- [ ] SecurityContext defined on all containers (not just pod level)
- [ ] Secrets not hardcoded in manifests (use external-secrets, sealed-secrets, or vault)
- [ ] RBAC follows least privilege (no `cluster-admin` ClusterRoleBinding for applications)
- [ ] NetworkPolicies defined (default deny ingress + explicit allow rules)
- [ ] Service accounts with `automountServiceAccountToken: false` (unless needed)
- [ ] No `hostNetwork: true`, `hostPID: true`, or `hostIPC: true` unless justified
- [ ] Container images from trusted registries only
- [ ] No `CAP_SYS_ADMIN` or other dangerous capabilities added

## Reliability Checklist

- [ ] Resource `requests` AND `limits` defined for all containers
- [ ] Liveness probes configured (with appropriate `initialDelaySeconds`)
- [ ] Readiness probes configured (separate from liveness)
- [ ] PodDisruptionBudgets defined for critical deployments
- [ ] Topology spread constraints or anti-affinity for HA
- [ ] `replicas >= 2` for production deployments
- [ ] `terminationGracePeriodSeconds` appropriate for the workload
- [ ] `preStop` hooks for graceful shutdown if needed

## Best Practices Checklist

- [ ] Labels consistent across resources (`app`, `version`, `team`, `environment`)
- [ ] Image tags are specific (no `:latest` in production)
- [ ] Namespace isolation (not everything in `default`)
- [ ] HPA configured for variable workloads
- [ ] Resource quotas defined per namespace
- [ ] ConfigMaps and Secrets referenced exist
- [ ] Annotations for monitoring/alerting tools present
- [ ] `.spec.revisionHistoryLimit` set to reasonable value (e.g., 3-5)

## Output Format

```
================================================================
  KUBERNETES MANIFEST REVIEW
  Project: [project-name] | Files analyzed: [count]
================================================================

SCORES
  Security:       X/10
  Reliability:    X/10
  Best Practices: X/10

--- CRITICAL (must fix) ----------------------------------------

[CRITICAL] Finding title
  File: path/to/file.yaml (line XX)
  Issue: What's wrong
  Risk: Why this matters
  Fix:
    [YAML diff showing the fix]

--- WARNINGS (should fix) --------------------------------------

[WARNING] Finding title
  File: ...
  Issue: ...
  Fix: ...

--- RECOMMENDATIONS (nice to have) -----------------------------

[RECOMMEND] Finding title
  File: ...
  Suggestion: ...
```

## Tips
- Run this skill before every deployment to production
- Pair with `/k8s-debug` for post-deploy cluster health checks
- Use in CI/CD pipelines for automated manifest validation
- For Terraform-managed Kubernetes resources, also run `/terraform-review`
