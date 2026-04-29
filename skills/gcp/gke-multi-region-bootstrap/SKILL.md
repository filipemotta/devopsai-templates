---
name: gke-multi-region-bootstrap
description: Provision GKE Autopilot clusters across multiple regions in parallel using an Agent Team. Each regional subagent creates VPC, subnets, Cloud NAT, the cluster with Workload Identity and Dataplane V2, baseline namespaces, and validates first 5 minutes for zero Warning events. The orchestrator runs a reconciliation pass to detect cross-region drift before incidents. Activates when bootstrapping multi-region GKE infrastructure, expanding into new regions, or migrating from single-region to multi-region. Supports dry_run mode that produces JSON plans without applying.
allowed-tools:
  - mcp__gke__check_k8s_auth
  - mcp__gke__list_clusters
  - mcp__gke__get_cluster
  - mcp__gke__create_cluster
  - mcp__gke__update_cluster
  - mcp__gke__create_node_pool
  - mcp__gke__apply_k8s_manifest
  - mcp__gke__list_k8s_events
  - mcp__gke__get_k8s_rollout_status
  - mcp__gke__get_operation
  - mcp__gke__list_operations
  - mcp__compute__*
  - mcp__cloud_logging__list_log_entries
  - mcp__resource_manager__search_projects
  - Task
  - Bash(gcloud:*)
  - Read
  - Write
---

# /gke-multi-region-bootstrap

Provision identical GKE Autopilot clusters in N regions using an orchestrator + per-region subagents. Designed for green-field bootstraps where the cost of subtle cross-region drift is high.

## Invocation

```
/gke-multi-region-bootstrap regions=<list> project=<id> cidr_pattern=<pattern> [dry_run=true|false]
```

**Parameters:**
- `regions` (required): comma-separated GCP regions, e.g. `us-central1,europe-west1,asia-southeast1`
- `project` (required): GCP project ID
- `cidr_pattern` (required): CIDR template using `{idx}` placeholder, e.g. `10.{idx}0.0.0/16` produces `10.10.0.0/16`, `10.20.0.0/16`, `10.30.0.0/16`
- `dry_run` (default: `true`): when true, produces JSON plan only; no API mutation
- `release_channel` (default: `REGULAR`): `RAPID`, `REGULAR`, or `STABLE`
- `master_authorized_cidrs` (optional): comma-separated CIDRs allowed to reach control plane

## Hard Requirements (NEVER violate)

1. **Private cluster only** — `private_cluster=true`, no public endpoint exposed.
2. **Workload Identity ON** — required for all workloads.
3. **Dataplane V2 (eBPF/Cilium) ON** — for network policy and observability.
4. **No `roles/owner` or `roles/editor`** on any service account created.
5. **Stop and request approval** if the region already contains a cluster with prefix `prod-`.
6. **Reconciliation pass mandatory** — orchestrator MUST diff regional outputs and surface drift before declaring success.

## Orchestrator Flow

### Phase 0 — Pre-flight (sequential, read-only)

```
For each region in regions:
  1. mcp__resource_manager__search_projects(filter=f"projectId:{project}")
     → confirm project exists and we have access
  2. mcp__gke__list_clusters(project, region)
     → check for existing prod-* prefix; abort if found
  3. Bash: gcloud services list --enabled --project={project}
     → confirm container.googleapis.com, compute.googleapis.com, logging.googleapis.com enabled
```

### Phase 1 — Parallel regional provisioning

Spawn one `gke-regional-provisioner` subagent per region using `Task` tool. All run in parallel.

Subagent input:
```json
{
  "region": "us-central1",
  "project": "my-prod-project",
  "cidr_block": "10.10.0.0/16",
  "release_channel": "REGULAR",
  "dry_run": true|false,
  "idx": 1
}
```

Subagent expected output:
```json
{
  "region": "us-central1",
  "cluster_name": "prod-us-central1",
  "vpc_self_link": "projects/.../global/networks/prod-vpc-us",
  "kubeconfig_context": "gke_my-prod-project_us-central1_prod-us-central1",
  "release_channel": "REGULAR",
  "workload_identity": "my-prod-project.svc.id.goog",
  "dataplane_v2": true,
  "addons_enabled": ["NetworkPolicy", "HttpLoadBalancing", "HorizontalPodAutoscaling"],
  "labels": {"env": "prod", "region": "us", "managed-by": "agent-team"},
  "operations": ["projects/.../operations/operation-xxx"],
  "warnings_in_first_5min": 0,
  "status": "ready" | "needs_review",
  "dry_run_plan": null | { /* full request body if dry_run=true */ }
}
```

### Phase 2 — Global shared resources (parallel with Phase 1)

Spawn one `gcp-global-shared` subagent for org-wide resources:
- Cloud DNS zone for the new domain (if requested)
- Org policy bindings (e.g. `compute.requireShieldedVm`)
- Billing labels for cost allocation
- Monitoring workspace if not yet created

### Phase 3 — Reconciliation (orchestrator only)

Compare the N regional outputs. For each field, flag any value that differs from the majority:
- `release_channel` MUST match across all regions
- `dataplane_v2` MUST be `true` everywhere
- `workload_identity` MUST be set everywhere
- `addons_enabled` lists MUST match (sorted)
- `labels.env` MUST match
- Any `warnings_in_first_5min > 0` MUST be investigated

Output the reconciliation table:

```
| Field              | us-central1   | europe-west1  | asia-southeast1 | Status |
|--------------------|---------------|---------------|-----------------|--------|
| release_channel    | REGULAR       | REGULAR       | REGULAR         | ✓      |
| dataplane_v2       | true          | true          | true            | ✓      |
| addons             | [3 enabled]   | [3 enabled]   | [3 enabled]     | ✓      |
| warnings_5min      | 0             | 2             | 0               | ⚠      |
```

### Phase 4 — Final report

If `dry_run=true`: collect the `dry_run_plan` JSON from each subagent into a single `bootstrap-plan.json` for human review. Print path and stop.

If `dry_run=false` and reconciliation has zero ⚠: declare success, output kubeconfig context per region, and provide next-step suggestions:
- "Configure ArgoCD multi-cluster (see skills/gitops)"
- "Apply baseline RBAC via gke-rbac-baseline skill"

If reconciliation surfaces ⚠: do NOT declare success. Output the drift table and ask the user to decide: re-run the affected region, accept drift, or rollback.

## Subagent Definition (auto-created if missing)

The Skill auto-creates `.claude/agents/gke-regional-provisioner.md` with the spec below if it doesn't exist:

```yaml
---
name: gke-regional-provisioner
description: Provisions a single-region GKE Autopilot cluster with VPC, Workload Identity, Dataplane V2, baseline namespaces. Returns structured JSON for orchestrator reconciliation.
tools:
  - mcp__gke__check_k8s_auth
  - mcp__gke__create_cluster
  - mcp__gke__get_cluster
  - mcp__gke__apply_k8s_manifest
  - mcp__gke__list_k8s_events
  - mcp__gke__get_k8s_rollout_status
  - mcp__gke__get_operation
  - mcp__compute__create_network
  - mcp__compute__create_subnetwork
  - Bash(gcloud:*)
model: claude-opus-4-7
---

You receive: region, project, cidr_block, release_channel, dry_run, idx.

Steps (each step's output feeds the next):

1. Create VPC `prod-vpc-{region_short}` with custom subnet routing.
2. Create primary subnet `prod-nodes-{region}` with the given cidr_block;
   add secondary ranges `pods-{region}` (/14 inside the /16) and `services-{region}` (/20).
3. Create Cloud NAT for egress (no public IPs on nodes).
4. Call mcp__gke__create_cluster with:
   - autopilot=true
   - private_cluster=true
   - workload_identity_pool=f"{project}.svc.id.goog"
   - dataplane_v2=true
   - release_channel=release_channel
   - labels={env:prod, region:{region}, managed-by:agent-team}
   - master_authorized_networks=master_authorized_cidrs (if provided)
5. Wait for the operation to complete via mcp__gke__get_operation polling.
6. Apply baseline namespaces: monitoring, ingress, platform-system with ResourceQuota
   limiting CPU/RAM/PVC counts (defaults: 100 vCPU, 200Gi, 50 PVCs).
7. After 5 minutes, call mcp__gke__list_k8s_events with field_selector="type!=Normal"
   and count Warnings.
8. Return the JSON shape specified by the orchestrator.

If dry_run=true: skip steps 1-6, return only the planned create_cluster body
in dry_run_plan and set status="ready".

NEVER:
- Enable cluster public endpoint
- Create service accounts with role/owner or role/editor
- Disable Workload Identity
- Disable Dataplane V2
- Use the default network or default subnet
```

## Failure Modes & Recovery

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Region quota exceeded | `create_cluster` returns RESOURCE_EXHAUSTED | Pause that region, suggest quota increase, continue others |
| Master CIDR conflict | `create_cluster` returns INVALID_ARGUMENT | Auto-pick next /28 from configured pool |
| Workload Identity not propagated | `apply_k8s_manifest` for KSA fails after cluster ready | Retry with exponential backoff (max 3) |
| First 5min warnings | Phase 3 reconciliation flags ⚠ | Do not declare success; surface events and ask |
| Subagent timeout | Task tool returns timeout | Mark region as `needs_review`, do not auto-rollback |

## Cost Disclosure

A successful run typically costs:
- **GKE control plane fee**: Autopilot is free for the cluster, you pay only per pod request
- **Cloud Build minutes**: 0 (no builds triggered by bootstrap)
- **Claude session**: ~5,000–10,000 tokens for the orchestrator + ~3,000 per regional subagent. With Opus 4.7 pricing, expect under US$ 10 for a 3-region bootstrap.

## Integration with the Guide

This skill implements the flow described in:
- **Section 6.18** (Agent Team — Multi-Region GKE Provisioning) — the practical flow
- **Section 3.16** (GCP MCP Servers) — the underlying MCP setup
- **Section 12.3** (Guardrails) — the read-first / dry-run-first pattern
