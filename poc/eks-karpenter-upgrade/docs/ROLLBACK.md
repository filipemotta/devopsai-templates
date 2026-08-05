# Rollback Runbook — The Five Layers

"Rollback is a revert" is a slogan. A Git revert restores declared intent, and
each layer of the cluster converges back to that intent through its own path.
This runbook names the five layers separately, in the order you would walk
them. Rehearse it once in a non critical environment: a rollback that has
never run is a document, not a capability.

## Layer 0 — Decide WHERE you are before deciding what to do

The cost of rollback depends entirely on whether the data plane has moved.

| State | Rollback cost |
|---|---|
| Control plane on N+1, nodes still on N (bake state) | Cheapest possible: revert the control plane, nothing else moves |
| Nodes already rotated to N+1 | Nodes must return to N BEFORE the control plane can revert (skew policy: kubelet never newer than API server) |

This asymmetry is the strongest argument for the bake stage in the runbook.

## Layer 1 — Git

Revert the commit that bumped the version variables (AMI pin, addon versions,
cluster version). This restores intent. Nothing has converged yet.

## Layer 2 — Nodes (the Karpenter trap)

A versioned alias (`al2023@v20250701`) CANNOT take kubelets back to N while
the control plane is still on N+1: the alias keeps resolving against the
current control plane version. To roll nodes back you need one of:

- an `EC2NodeClass` with an explicit AMI id for the N-compatible image:
  ```
  amiSelectorTerms:
    - id: ami-XXXXXXXXXXXXXXXXX   # the exact N-version image you were running
  ```
  (record this AMI id during step 1 preflight, while it is trivially available:
  `kubectl get nodes -o jsonpath='{.items[0].spec.providerID}'` then
  `aws ec2 describe-instances` for the ImageId)
- or a dedicated blue and green NodePool kept on the previous version for
  exactly this purpose.

If you run blue and green, the rollback order matters: cordon the new pool,
restore selectors, affinity and tolerations to the old pool, confirm the old
pool has capacity and eligibility, and only then drain the new pool's nodes.
Drain first and evicted pods that still demand new pool labels sit Pending
while you revert rules under pressure.

## Layer 3 — Addons

Explicit downgrade per compatibility matrix (`aws eks update-addon` with the
previous version and `--resolve-conflicts PRESERVE`). Reverting Git does not
perform this; a reconciler or a human does.

## Layer 4 — Control plane (the 7 day window)

EKS supports rolling the control plane back one minor version within seven
days of the upgrade, as an explicit operation through the console, CLI or
SDKs. EKS evaluates rollback readiness insights first (API compatibility,
version skew, addon compatibility, cluster health). The revert preserves
etcd data, workloads and persistent volumes.

References:
- Announcement: https://aws.amazon.com/about-aws/whats-new/2026/07/amazon-eks-version-rollback/
- Launch blog: https://aws.amazon.com/blogs/aws/upgrade-amazon-eks-clusters-with-confidence-using-kubernetes-version-rollbacks/

Check the exact CLI invocation in the current documentation before you need
it under pressure, and confirm the readiness insights are green: if nodes
are still on N+1, the skew insight will (correctly) block you until Layer 2
is done.

## Layer 5 — CRDs and stored objects

The least reversible layer. Once controllers have written new schema versions
into etcd, going backwards is a migration question, not a Git question. For
upgrades that involve CRD schema changes (including Karpenter's own), read
the project's downgrade notes BEFORE the upgrade, and treat "no downgrade
path documented" as meaning exactly that.

## The drill

1. In a non critical cluster, walk steps 1 through 7 of the POC.
2. Then execute this runbook back to N, layer by layer, timing each one.
3. Write the timings into your wave review checklist: the time to roll back
   is the number that decides between drift with conservative budgets and
   blue and green for your production fleets.
