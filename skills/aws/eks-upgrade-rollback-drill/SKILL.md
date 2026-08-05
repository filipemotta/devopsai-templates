---
name: eks-upgrade-rollback-drill
description: Guided rollback rehearsal for EKS upgrades. Activates after an upgrade completes in a non-critical environment, or when planning production rollback strategy. Walks the five rollback layers (Git, nodes, addons, control plane, CRDs), times each one, and produces the evidence that decides between drift and blue/green for production fleets.
---

# EKS Upgrade Rollback Drill Skill

## Purpose
You are a Senior Platform Engineer rehearsing a rollback, layer by layer. A rollback procedure that has never run is a document, not a capability. This skill turns the document into a capability, and produces the timing data that real fleet decisions are made from.

## Usage
```
/eks-upgrade-rollback-drill <cluster-name>
```

## Before Anything: Locate the Cluster State

The cost of rollback depends entirely on whether the data plane has moved:

| State | Rollback cost |
|---|---|
| Control plane on N+1, nodes still on N (bake state) | Cheapest possible: revert the control plane, nothing else moves |
| Nodes already rotated to N+1 | Nodes must return to N BEFORE the control plane can revert (skew policy: kubelet never newer than API server) |

Report which state the cluster is in and adjust the layer order accordingly.

## The Five Layers

### Layer 1 — Git
Revert the commit that bumped the version variables (AMI pin, addon versions, cluster version). This restores **intent**. Nothing has converged yet. Say so explicitly in the drill log.

### Layer 2 — Nodes (the Karpenter trap)
A versioned alias CANNOT take kubelets back to N-1 while the control plane is on N: the alias keeps resolving against the current control plane version. Guide the operator through one of:
- An EC2NodeClass with the **explicit N-1 AMI ID** (recorded during preflight):
```yaml
amiSelectorTerms:
  - id: ami-XXXXXXXXXXXXXXXXX
```
- Or a dedicated blue/green NodePool kept on the previous version.

For blue/green, enforce the order: **cordon the new pool → restore selectors/affinity/tolerations → confirm old pool capacity and eligibility → only then drain**. Draining first strands evicted pods as Pending.

### Layer 3 — Addons
Explicit downgrade per compatibility matrix:
```bash
aws eks update-addon --cluster-name <CLUSTER> --addon-name <ADDON> \
  --addon-version <PREVIOUS_VERSION> --resolve-conflicts PRESERVE
```
Reverting Git does not perform this; a reconciler or a human does.

### Layer 4 — Control plane (the 7-day window)
EKS supports rolling the control plane back one minor version within 7 days of the upgrade. Before executing, EKS evaluates rollback readiness insights (API compatibility, version skew, addon compatibility, cluster health). The revert preserves etcd data, workloads and persistent volumes.
- If nodes are still on N+1, the skew insight will (correctly) block until Layer 2 is done.
- Confirm the exact CLI invocation against current AWS documentation as part of the drill, not under pressure.

### Layer 5 — CRDs and stored objects
The least reversible layer. Once controllers have written new schema versions into etcd, going backwards is a migration question, not a Git question. For upgrades involving CRD schema changes (including Karpenter's own), read the project's downgrade notes BEFORE the upgrade and treat "no downgrade path documented" as meaning exactly that. In the drill, list every CRD whose schema changed in the upgrade and its documented downgrade story.

## Drill Output
Produce a drill report with:
1. Starting state (bake state or fully rotated)
2. Time taken per layer, measured, not estimated
3. Anything that blocked (PDB stalls, readiness insights, missing AMI ID) and how it was resolved
4. The go-forward recommendation: with these timings, does this fleet's production tier warrant blue/green NodePools or drift with conservative budgets?
5. Items to fix before the next real upgrade (e.g., AMI ID not recorded in preflight, downgrade notes missing for a CRD)

## Hard Rules
- Never run the drill for the first time in production.
- The 7-day window is a bake timer: recommend wave promotion schedules that keep each wave's soak inside it.
- If the drill has never been run for a fleet, flag every production upgrade plan for that fleet as CONDITIONAL.
