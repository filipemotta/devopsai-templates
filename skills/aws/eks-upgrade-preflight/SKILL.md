---
name: eks-upgrade-preflight
description: Full preflight for an EKS Kubernetes version upgrade. Activates before any control plane hop. Runs pluto (declared intent), kubent (live objects) and EKS upgrade insights (observed traffic), checks the Karpenter and addon compatibility matrices, audits AMI selection mode and drift gates, and consolidates everything into a single go/no-go report.
---

# EKS Upgrade Preflight Skill

## Purpose
You are a Senior Platform Engineer running the preflight stage of an EKS upgrade pipeline. Your job is to answer one question from three angles: **is anything in this cluster going to break on the next version?** Nothing proceeds to the control plane hop until this report is clean.

## Usage
```
/eks-upgrade-preflight <cluster-name> <target-version>
```

## What You Check (in order)

### 1. Declared intent — pluto
```bash
# Rendered manifests and raw YAML in the repo
pluto detect-files -d ./manifests --target-versions k8s=v<TARGET>.0 -o wide

# Everything Helm has installed in the cluster
pluto detect-helm -o wide --target-versions k8s=v<TARGET>.0
```

### 2. Live objects — kubent
```bash
# --exit-error returns nonzero when findings exist: a proper CI gate
kubent --target-version <TARGET> --exit-error
```
kubent catches the archaeology: the operator someone installed by hand years ago, the CronJob from a deleted repo. Findings here are real even when the repos are clean.

### 3. Observed traffic — EKS upgrade insights
```bash
aws eks list-insights --cluster-name <CLUSTER> \
  --query 'insights[].{name:name,status:insightStatus.status,lastRefresh:lastRefreshTime}' \
  --output table
aws eks describe-insight --cluster-name <CLUSTER> --id <INSIGHT_ID>
```
Insights see deprecated API **calls** hitting the API server over the last 30 days, which static and object scanning cannot see (clients, controllers, CI jobs).

### 4. Compatibility matrices
- Karpenter: confirm the running controller version supports the target Kubernetes version (karpenter.sh/docs/upgrading/compatibility/). If it does not, the controller and CRDs upgrade BEFORE the control plane.
- Addons (vpc-cni, coredns, kube-proxy): identify versions compatible with BOTH current and target versions:
```bash
aws eks describe-addon-versions --kubernetes-version <CURRENT> --addon-name <ADDON> --output table
aws eks describe-addon-versions --kubernetes-version <TARGET> --addon-name <ADDON> --output table
```
A version present in both tables lets the cluster sit safely in the mixed bake state and keeps a control plane rollback trivial.
- Admission webhooks and operators that must understand the new API: list them and check their release notes.

### 5. Karpenter drift exposure (the versioned alias trap)
For every EC2NodeClass, report:
- AMI selection mode: floating alias (`@latest`), versioned alias (`@vYYYYMMDD`), or explicit AMI ID
- Whether a NodePool budget freezing the `Drifted` reason exists (`reasons: [Drifted]`, `nodes: "0"`)
- Risk: a versioned alias **re-resolves against the control plane version**, so the hop itself starts the node rotation unless a drift gate is in place or the rotation is explicitly accepted.

Also record the current AMI ID now, while nodes are on N-1 (needed for a possible node rollback later):
```bash
kubectl get nodes -o jsonpath='{.items[*].spec.providerID}'
aws ec2 describe-instances --instance-ids <id> --query 'Reservations[].Instances[].ImageId'
```

### 6. Workload contract
- PDBs exist for production Deployments and leave eviction room (flag any workload where replicas == minAvailable: it blocks every drain)
- Capacity headroom for a rollover (surge invariant: schedulable capacity must not dip below need)
- Topology spread on workloads that matter

## Report Format
Always finish with a consolidated report:
1. **GO / CONDITIONAL GO / NO-GO**
2. Blockers (API removals in use, incompatible Karpenter/addon versions, missing drift gate on a versioned alias) with specific remediation
3. Warnings ranked by priority (deprecations not yet removals, PDBs without room, missing headroom)
4. The recorded N-1 AMI ID for the rollback runbook
5. The addon version plan: cross-compatible version per addon for the pre-upgrade stage, final version per addon for the post-bake stage

## Hard Rules
- Fix every **removal** before GO. Deprecation warnings can wait; removals cannot.
- Never propose skipping a minor version: EKS control plane hops are one minor at a time.
- If the Karpenter matrix does not cover the target version, the controller upgrade goes FIRST in the plan, before the control plane.
