# EKS Upgrade with Karpenter — Reproducible POC

Companion repository for the article **"Upgrading EKS with Karpenter: From One
Cluster to Three Hundred"**. The article explains the reasoning; this repo lets
you rehearse the runbook on a real cluster in an afternoon.

> Companion to section 7.20 of The DevOps AI Official Guide. Pair it with the
> AI layer in this repository: `CLAUDE-eks-upgrade.md`, the
> `skills/aws/eks-upgrade-preflight` and
> `skills/aws/eks-upgrade-rollback-drill` skills, and the
> `subagents/eks-upgrade-validator.md` subagent.

The exercise: bring up an EKS cluster at **N-1** (1.32), then perform the
upgrade to **N** (1.33) by hand, following the same eight steps the article
describes, including the drift gate, the bake stage and the layered rollback.

## What this POC demonstrates

- Karpenter **drift** as the node upgrade engine, with disruption budgets as brakes
- The **versioned alias trap**: a pinned `al2023@vYYYYMMDD` alias still re-resolves
  when the control plane version changes, so the hop can start the rotation by itself
- The **drift gate**: freezing the `Drifted` reason to make rotation a deliberate step
- The **bake state** (control plane on N+1, nodes on N) as the cheapest rollback point
- Correct **budgets**: scoped by reason, explicit consolidation limit, UTC schedules
- `expireAfter` + `terminationGracePeriod` as a pair, and why expiration is **forceful**
- Workload prerequisites: **PDB with eviction room**, surge, graceful shutdown
- The **five layer rollback**, including the native EKS control plane rollback window

## Repository layout

```
.
├── README.md                          <- you are here
├── config.env.example                 <- copy to config.env, sourced by all scripts
├── terraform/
│   ├── versions.tf                    <- providers
│   ├── variables.tf                   <- cluster at N-1, Karpenter version (check the matrix)
│   ├── main.tf                        <- VPC, EKS, bootstrap MNG for Karpenter, Helm release
│   └── outputs.tf
├── manifests/
│   ├── ec2nodeclass.yaml              <- pinned alias + the re-resolution warning
│   ├── nodepool.yaml                  <- budgets with all three production gotchas documented
│   ├── nodepool-drift-frozen.yaml     <- the drift gate applied before the hop
│   └── sample-app/
│       ├── deployment.yaml            <- graceful shutdown, probes, topology spread
│       └── pdb.yaml                   <- minAvailable with eviction room + AlwaysAllow
├── scripts/
│   ├── 01-preflight.sh                <- pluto + kubent + EKS upgrade insights
│   ├── 02-pre-upgrades.sh             <- cross compatible addon versions, Karpenter if needed
│   ├── 03-freeze-drift.sh             <- the gate, BEFORE the control plane
│   ├── 04-upgrade-control-plane.sh    <- one minor per hop
│   ├── 05-bake-validate.sh            <- the mixed state checks
│   ├── 06-finalize-addons.sh          <- recommended versions for N, config preserved
│   └── 07-release-rotation.sh         <- lift the freeze, watch drift work
└── docs/
    └── ROLLBACK.md                    <- step 8: the five layer rollback runbook
```

## Cost warning

This POC creates real, billable resources: an EKS cluster (~$0.10/hour for the
control plane), a NAT gateway, 2x t3.medium bootstrap nodes and whatever
Karpenter provisions for the sample app (typically 1 to 2 small instances).
Rough order of magnitude: **a few dollars for an afternoon**. Run
`terraform destroy` when you finish (teardown section below).

## Prerequisites

- AWS account with permissions for EKS, EC2, IAM, VPC and SQS
- `terraform` >= 1.5, `kubectl`, `helm`, `aws` CLI v2 authenticated
- [`pluto`](https://github.com/FairwindsOps/pluto) and
  [`kubent`](https://github.com/doitintl/kube-no-trouble) installed
- Before starting: open the
  [Karpenter compatibility matrix](https://karpenter.sh/docs/upgrading/compatibility/)
  and confirm the version in `terraform/variables.tf` supports both 1.32 and 1.33.
  If it does not, that is not a blocker, it is the lesson of step 2.

## Setup (once)

```
cd terraform
terraform init
terraform apply
aws eks update-kubeconfig --region us-east-1 --name karpenter-upgrade-poc
cd ..
cp config.env.example config.env      # adjust region/name if you changed them
```

Deploy the Karpenter resources and the sample workload. Before applying,
update two values for the day you run this: the AMI alias release in
`manifests/ec2nodeclass.yaml` (pick the current release for 1.32) and, if you
changed the cluster name, the discovery tags and role name in the same file.

```
kubectl apply -f manifests/ec2nodeclass.yaml
kubectl apply -f manifests/nodepool.yaml
kubectl apply -f manifests/sample-app/
kubectl get nodeclaims -w     # watch Karpenter provision capacity for the sample app
```

**Record the current AMI id now** (you will want it for the rollback drill,
and it is trivially available while nodes are on N-1):

```
kubectl get nodes -o jsonpath='{.items[*].spec.providerID}'
# then: aws ec2 describe-instances --instance-ids <id> --query 'Reservations[].Instances[].ImageId'
```

## The runbook — eight steps

Each step maps to the article section of the same name. Run them in order and
read the comments inside each file: the comments carry the reasoning.

| Step | What happens | Run / read |
|---|---|---|
| **1. Preflight** | pluto (intent), kubent (reality), EKS insights (observed traffic). Fix removals; check matrices, PDBs, headroom | `scripts/01-preflight.sh` |
| **2. Move what must precede** | Addons to versions compatible with BOTH 1.32 and 1.33; Karpenter first if the matrix demands | `scripts/02-pre-upgrades.sh` |
| **3. Gate the rotation** | Freeze `Drifted` before the hop, because the pinned alias will re-resolve when the version changes | `scripts/03-freeze-drift.sh`, `manifests/nodepool-drift-frozen.yaml` |
| **4. Control plane** | One minor per hop. With the gate on, nothing about the nodes moves. The 7 day rollback window starts now | `scripts/04-upgrade-control-plane.sh` |
| **5. Bake** | Control plane on N+1, nodes on N. Validate controllers, webhooks, insights. This is the cheapest rollback point; do not rush it | `scripts/05-bake-validate.sh` |
| **6. Finalize addons** | Promote to the recommended versions for 1.33, `--resolve-conflicts PRESERVE` | `scripts/06-finalize-addons.sh` |
| **7. Release the rotation** | Restore the real budgets, watch drift replace nodes at the pace the budgets allow. Take notes: convergence time, PDB stalls | `scripts/07-release-rotation.sh`, `manifests/nodepool.yaml` |
| **8. Rollback drill** | Walk the five layers back at least once: Git, nodes (explicit AMI id, the alias will not resolve backwards), addons, control plane window, CRDs | `docs/ROLLBACK.md` |

Run the sequence twice on the same cluster and the fear is gone. That is the
whole trick: upgrades stop being scary the moment they stop being special.

## What to watch during step 7

```
kubectl get nodes -w -o custom-columns='NODE:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,READY:.status.conditions[-1].type'
kubectl get pods -A --field-selector=status.phase=Pending -w
kubectl get nodeclaims
kubectl get pdb -A        # ALLOWED DISRUPTIONS stuck at 0 = a stall worth understanding
```

## Experiments worth running after the happy path

1. **The alias trap, live**: rerun the POC without step 3 and watch the
   control plane hop start the rotation on its own. Now the warning in
   `manifests/ec2nodeclass.yaml` is an experience, not a comment.
2. **The PDB stall**: scale `sample-web` to 2 replicas (with `minAvailable: 2`)
   and watch the drain block forever. Then read the arithmetic comment in
   `manifests/sample-app/pdb.yaml`.
3. **Forceful expiration**: set `expireAfter: 1h` in the NodePool and observe
   that budgets do not pace the expirations, only `terminationGracePeriod`
   bounds the exit.
4. **Rounding up**: with a 3 node pool and a `10%` Drifted budget, confirm one
   node still rotates (ceil, effectively 33%).

## Teardown

```
kubectl delete -f manifests/sample-app/ --ignore-not-found
kubectl delete -f manifests/nodepool.yaml --ignore-not-found
kubectl delete -f manifests/ec2nodeclass.yaml --ignore-not-found
# wait for Karpenter-provisioned instances to terminate, then:
cd terraform && terraform destroy
```

## Scope

This POC covers one cluster end to end. The fleet dimension of the article
(waves across 300 clusters, GitOps with layered reconcilers, criticality
tiers) is organizational architecture and intentionally out of scope here;
blue and green NodePools are described in `docs/ROLLBACK.md` and left as an
exercise. None of this is tuned for production as-is: it is a rehearsal space.

## License

MIT. Use it, break it, rehearse on it.
