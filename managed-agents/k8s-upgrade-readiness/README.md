# Kubernetes upgrade readiness with Managed Agents (worker inside the cluster)

A scheduled Claude Managed Agents deployment that checks, every week, whether an EKS cluster is
ready for its next minor version, and keeps one GitHub issue per cluster and target version with the
verdict (READY / NOT READY / INCOMPLETE), the blockers and the trend since last week.
Companion to sections 7.13.10 / 7.13.11 of *The AI-Native DevOps Engineer*.

## Why it is built this way

- **The worker runs as a pod in the cluster it inspects.** The Managed Agents worker runs tools in
  process, so every `kubectl` and `aws` call inherits the pod's ServiceAccount and EKS Pod Identity
  role. No kubeconfig or cloud key leaves the cluster; the only secret in the pod is the environment
  key, scoped to this one environment's queue.
- **A custom read-only ClusterRole, not `view`.** `view` also reads ConfigMaps, and every tool output
  goes to the model. The role reads nodes, CRDs, APIServices, webhook configurations, PDBs and
  EndpointSlices, nothing else. No Secrets: Helm 3 keeps release manifests in Secrets, so
  `pluto detect-helm` stays in CI against the chart sources.
- **Live signals, not manifests.** Repository checks (pluto in CI) already catch deprecated
  `apiVersion`s in what you deploy. This scan covers what the repo cannot see: kubelet skew, CRD
  `status.storedVersions`, PDBs that will block drains, fail-closed webhooks without endpoints,
  unavailable APIServices, EKS upgrade insights (audit-log based, with the user agent of each client
  still calling a deprecated API) and managed add-on versions offered for the target.
- **Names and counts only.** `readiness-scan.sh` prints one JSON with names, versions and counts.
- **Memory vs decisions.** The `readiness-ledger` memory store keeps history (first seen, request
  trends). Accepted exceptions live in `gitops/accepted.yaml`, merged by a human, with an expiry.

## Layout

```
platform-agents/                         # applied with `ant apply` (plan on PR, apply on merge)
  agents/k8s-upgrade-readiness.md        # Sonnet 5.5, GitHub MCP with 3 tools only, no web tools
  deployments/weekly-readiness.md        # cron 0 6 * * 1 UTC, US$ 3 budget per run
  environments/readiness-runner.yaml     # type: self_hosted, dedicated to this agent
  memory_stores/readiness-ledger.yaml
  vaults/github-readiness.yaml           # name only; the PAT goes in through the CLI
k8s/
  rbac.yaml                              # namespace, ServiceAccount, read-only ClusterRole
  worker.yaml                            # ConfigMap (target version), Deployment, NetworkPolicy
  iam-policy.json, iam-trust-policy.json # Pod Identity role: EKS insights + add-on reads only
worker/
  Dockerfile                             # ant + kubectl + aws CLI + jq, non-root
  readiness-scan.sh                      # the only command the agent runs
gitops/accepted.yaml                     # human-approved exceptions -> ConfigMap readiness-exceptions
```

## Setup

```bash
# 1. Identity (once per cluster). Requires the eks-pod-identity-agent add-on.
aws iam create-role --role-name upgrade-readiness-reader \
  --assume-role-policy-document file://k8s/iam-trust-policy.json
aws iam put-role-policy --role-name upgrade-readiness-reader \
  --policy-name eks-readiness-read --policy-document file://k8s/iam-policy.json
kubectl apply -f k8s/rbac.yaml
aws eks create-pod-identity-association --cluster-name prod-eu \
  --namespace upgrade-readiness --service-account readiness-scanner \
  --role-arn arn:aws:iam::111122223333:role/upgrade-readiness-reader

# 2. Environment key (generated in the Console) as a Kubernetes Secret, from your secrets manager
kubectl -n upgrade-readiness create secret generic anthropic-environment \
  --from-literal=id="$ANTHROPIC_ENVIRONMENT_ID" --from-literal=key="$ANTHROPIC_ENVIRONMENT_KEY"

# 3. Worker (normally through Argo CD / Flux, together with the readiness-exceptions ConfigMap)
kubectl apply -f k8s/worker.yaml

# 4. Agent, memory store, vault, deployment (from your machine or CI, with the API key)
ant apply --dry-run platform-agents/ && ant apply platform-agents/
ant beta:environments:work stats --environment-id "$ANTHROPIC_ENVIRONMENT_ID"   # workers_polling >= 1
ant beta:deployments run --deployment-id "$DEPLOYMENT_ID"                       # rehearsal before the cron
```

## What it never does

Upgrade the control plane or nodes, bump add-ons, delete or relax PDBs, migrate CRD storage,
remove webhooks, or edit `accepted.yaml`. Every one of those is a reviewed change.

## Limits

- EKS-specific checks (insights, add-ons) need EKS; on other clusters the scan reports them under
  `scan_errors` and the verdict is INCOMPLETE until you remove those blocks from the script.
- Memory stores cannot be attached to self-hosted sessions on Claude Platform on AWS.
- Tool inputs and outputs are sent to Anthropic so the model can read them; keep the scan output
  free of data you would not put in a ticket.
