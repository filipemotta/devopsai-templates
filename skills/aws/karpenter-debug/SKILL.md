---
name: karpenter-debug
description: Automatically diagnose Karpenter issues — provisioning failures, consolidation problems, NodeClaim lifecycle issues. Collects cluster state and returns structured report with severity, evidence, and remediation steps.
---

# /karpenter-debug

## Purpose
Automate Karpenter troubleshooting by collecting cluster state, analyzing it against known failure patterns, and returning a structured diagnostic report.

## Data Collection (run sequentially)

```bash
# 1. NodeClaim state (are nodes launching/registering/initializing?)
kubectl get nodeclaims -o wide

# 2. NodePool configuration and utilization vs limits
kubectl get nodepools -o yaml

# 3. Pending pods (trigger for provisioning)
kubectl get pods --field-selector=status.phase=Pending -A

# 4. Recent Karpenter events
kubectl get events --sort-by=.metadata.creationTimestamp | grep -i karpenter | tail -30

# 5. Controller logs (errors, capacity issues, launch failures)
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=200

# 6. NodePool utilization summary
kubectl get nodepool -o custom-columns=NAME:.metadata.name,CPU_LIMIT:.spec.limits.cpu,MEM_LIMIT:.spec.limits.memory
```

## Analysis Checklist

After collecting data, check each item:

### Provisioning Issues
- [ ] NodeClaims in `Unknown` or `Failed` state → check describe for LaunchFailed reason
- [ ] Pods `Pending` for more than 2 minutes → check if resource requests match any available instance type
- [ ] `InsufficientInstanceCapacity` in logs → diversify instance types (add families/sizes)
- [ ] `UnauthorizedOperation` in logs → IAM role missing ec2:RunInstances or ec2:CreateFleet
- [ ] NodePool `limits` reached → check cpu/memory usage vs configured limits
- [ ] Subnet IP exhaustion → check available IPs in configured subnets
- [ ] Missing Spot Service Linked Role → `aws iam create-service-linked-role --aws-service-name spot.amazonaws.com`

### Consolidation Issues
- [ ] Annotation `karpenter.sh/do-not-disrupt: "true"` on pods or nodes blocking consolidation
- [ ] PodDisruptionBudgets (PDBs) preventing eviction → `kubectl get pdb -A`
- [ ] Nodes not `Initialized` (Karpenter only consolidates initialized nodes)
- [ ] Disruption budget `nodes: "0"` active at current time (check schedule)
- [ ] `consolidateAfter` set too high (e.g., 24h)
- [ ] `consolidationPolicy: WhenEmpty` when `WhenEmptyOrUnderutilized` would be more effective
- [ ] Topology spread constraints preventing pod migration

### Node Lifecycle Issues
- [ ] Startup taints not being removed (kubelet didn't finish bootstrap)
- [ ] VPC CNI exhausted (no `vpc.amazonaws.com/pod-eni` available)
- [ ] Custom AMI issues (kernel incompatible, missing packages)
- [ ] Security Group blocking communication with API server (port 443)
- [ ] IMDS hop limit too restrictive (default 1 in v1, containers can't reach IMDS)

## Output Format

Return a structured report:

```
═══════════════════════════════════════════════════════
  KARPENTER DIAGNOSTIC REPORT
  Cluster: [cluster-name] | Time: [timestamp]
═══════════════════════════════════════════════════════

STATUS: [🟢 Healthy | 🟡 Warning | 🔴 Critical]

━━━ ISSUES FOUND ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[BLOCKER] Issue title
  Evidence: What was found in logs/events
  Impact: What this causes
  Fix: Specific command(s) to resolve

[WARNING] Issue title
  Evidence: ...
  Impact: ...
  Fix: ...

━━━ CLUSTER METRICS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NodePools:
  production: 12 nodes | CPU: 45/400 (11%) | Mem: 89/800Gi (11%)
  batch:       5 nodes | CPU: 38/200 (19%) | Mem: 62/400Gi (16%)

Capacity Types:
  On-Demand: 12 nodes | Spot: 5 nodes | Ratio: 71%/29%

NodeClaims:
  Ready: 15 | Pending: 2 | Unknown: 1

━━━ NEXT STEPS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. [Priority action]
2. [Secondary action]
```

## Tips
- Run this skill when pods are stuck Pending or costs are unexpectedly high
- Pair with `/karpenter-provision` to generate fixes for configuration issues
- For ongoing monitoring, integrate with Prometheus metrics (karpenter_nodepools_usage, karpenter_nodepools_limit)
