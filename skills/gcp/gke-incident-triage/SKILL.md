---
name: gke-incident-triage
description: Automated GKE incident triage with read-only-first discipline. Diagnoses pod failures (OOMKilled, CrashLoopBackOff, ImagePullBackOff, scheduling failures), latency spikes, and rollout problems by chaining GKE MCP read-only tools, Cloud Logging, and Cloud Monitoring. Produces a structured root-cause + remediation plan with two options (fast rollback vs forward fix), tools needed for each, and an explicit endpoint promotion request before any mutating call. Activates during on-call investigations and incident response.
allowed-tools:
  - mcp__gke__check_k8s_auth
  - mcp__gke__get_cluster
  - mcp__gke__get_k8s_cluster_info
  - mcp__gke__get_k8s_version
  - mcp__gke__list_k8s_events
  - mcp__gke__describe_k8s_resource
  - mcp__gke__get_k8s_resource
  - mcp__gke__get_k8s_logs
  - mcp__gke__get_k8s_rollout_status
  - mcp__gke__list_node_pools
  - mcp__gke__get_node_pool
  - mcp__cloud_logging__list_log_entries
  - mcp__cloud_logging__list_log_names
  - mcp__cloud_monitoring__query_range
  - mcp__cloud_monitoring__list_timeseries
  - mcp__cloud_monitoring__list_alerts
  - Read
---

# /gke-incident-triage

Read-only triage for GKE incidents. Returns a structured RCA + remediation plan; **does not** mutate cluster state.

## Invocation

```
/gke-incident-triage cluster=<name> [namespace=<ns>] [workload=<name>] [symptom=<description>]
```

**Parameters:**
- `cluster` (required): GKE cluster name
- `location` (optional): inferred from `gcloud config` if missing
- `namespace` (optional): scope investigation to a single namespace
- `workload` (optional): specific Deployment/StatefulSet/DaemonSet name
- `symptom` (optional): free text — "p99 latency spike", "OOMKilled loop", "rollout stuck"

If `symptom` is missing, the skill runs the full triage decision tree.

## Endpoint Discipline

All tool calls MUST hit `https://container.googleapis.com/mcp/read-only`. If the configured endpoint is `/mcp` (full) or `/mcp/delete-tools`, the skill MUST refuse and instruct the user to switch to read-only first. Mutation belongs to a separate session.

## Triage Decision Tree

### Step 0 — Auth & cluster sanity

```
mcp__gke__check_k8s_auth(cluster)
mcp__gke__get_cluster(name=cluster, location=location)
mcp__gke__get_k8s_version(cluster)
```

If `check_k8s_auth` fails → STOP, report missing IAM (`roles/container.viewer` minimum).
If cluster status != `RUNNING` → STOP, report cluster-level issue (likely upgrade or recreation in progress).

### Step 1 — Surface signals (parallel)

Issue these in parallel:

```
mcp__gke__list_k8s_events(
  cluster, namespace=namespace,
  field_selector="type!=Normal"
)
mcp__cloud_logging__list_log_entries(
  filter=f'resource.type="k8s_container" AND severity>=ERROR
           AND resource.labels.cluster_name="{cluster}"
           {f"AND resource.labels.namespace_name=\\"{namespace}\\"" if namespace else ""}
           AND timestamp>="-30m"',
  page_size=200
)
mcp__cloud_monitoring__list_alerts(
  project, time_range="-30m"
)
```

### Step 2 — Pattern matching

Match the collected signals against this pattern table. The first row that matches drives the next steps:

| Pattern | Signal | Drill-down tools | Likely root cause |
|---------|--------|-------------------|-------------------|
| OOMKilled loop | `list_k8s_events` shows `OOMKilled` events | `describe_k8s_resource` (Deployment) → `get_k8s_logs(previous=true)` → check `limits.memory` vs heap dump | Memory limit too low or memory leak in recent code |
| CrashLoopBackOff | Events `BackOff` + pod restartCount climbing | `get_k8s_logs(previous=true)` → check exit code, exception trace | App crash on startup or liveness probe misconfigured |
| ImagePullBackOff | Events `Failed to pull image` | `describe_k8s_resource` → check imagePullSecrets, image tag, registry IAM | Bad tag, missing pull secret, or Workload Identity binding wrong |
| Pending scheduling | Events `FailedScheduling` | `describe_k8s_resource` → check requests vs Autopilot quotas, nodeSelector | Autopilot can't satisfy resources or nodeSelector matches no node |
| Rollout stuck | `get_k8s_rollout_status` shows X/Y replicas after long timeout | Check `list_k8s_events` for the failing replica + describe the new ReplicaSet | Liveness probe too aggressive, or recent change broke startup |
| Latency spike (no events) | No abnormal events, but `query_range` shows p99 climbing | Compare deployment timestamp vs latency curve | Recent deploy correlates with latency — check resource usage |

### Step 3 — Latency-specific (if symptom indicates)

If symptom mentions latency or `query_range` shows degradation:

```
mcp__cloud_monitoring__query_range(
  query=(
    'histogram_quantile(0.99, '
    'sum by (le) (rate(http_request_duration_seconds_bucket'
    f'{{service="{workload}"}}[1m])))'
  ),
  start="-1h", end="now", step="60s"
)
```

Also check:
- `list_timeseries` for `kubernetes.io/container/cpu/core_usage_time` rate
- `list_timeseries` for `kubernetes.io/container/memory/used_bytes`
- Recent `Deployment` mutations: `describe_k8s_resource` → `metadata.annotations.deployment.kubernetes.io/revision`

Correlate: latency_inflection_time vs newest_revision.creationTimestamp.

### Step 4 — Output structure

Produce this report verbatim. Do NOT call any mutating tool — that's a separate decision.

```markdown
# GKE Incident Triage Report

**Cluster:** {cluster}
**Scope:** {namespace}/{workload}
**Time window:** last 30 minutes

## Root Cause

{1–3 sentence diagnosis with the specific evidence: which event, which log line, which metric}

**Evidence:**
- {tool}: {finding}
- {tool}: {finding}
- {tool}: {finding}

**Likely commit/change:** {if a deployment timestamp correlates}

## Remediation Options

### Option A — Fast Rollback (~3min, reversible)

{What this does, in one sentence}

**Tools needed (require /mcp full endpoint):**
- `patch_k8s_resource` — to set image back to {previous_sha}
- `get_k8s_rollout_status` — to confirm rollout

**Cost:** {what feature/capability is lost}

### Option B — Forward Fix (~Xmin)

{What this does — bump limit, add probe, etc.}

**Tools needed (require /mcp full endpoint):**
- {list}

**Cost:** {dollar/perf/risk impact}

## To Execute

This skill is read-only. To execute either option:

1. Switch your `.mcp.json` to the full endpoint configuration
2. Restart the Claude Code session
3. Use the explicit prompt: "Execute Option A from the triage report"

The agent will then have access to mutating tools and will:
- Perform the change
- Watch the rollout
- Validate via Cloud Monitoring that the metric returned to baseline
- Report the audit log entries (Cloud Audit Logs) for the change
```

## Hard Rules

1. **Never** call `apply_k8s_manifest`, `patch_k8s_resource`, `delete_k8s_resource`, `update_cluster`, `update_node_pool`, or any other mutating tool — they're not in this skill's allowed-tools.
2. **Never** suggest running `kubectl edit`, `kubectl apply -f`, or `kubectl delete` outside the agent — the goal is to keep the audit trail in Cloud Audit Logs, not in someone's shell history.
3. **Always** present at least two remediation options. If you genuinely see only one path, say so explicitly and explain why.
4. **Always** indicate the endpoint required for each tool (`read-only` vs `full /mcp`).
5. **Stop and ask** before drilling into PII-bearing logs (PIIDataset filters available; defer to user policy).

## Performance Notes

A typical run completes in 6–10 tool calls (one full cycle) over ~45 seconds. Latency-correlation cases may add 2–3 `query_range` calls for ~+30s.

## Integration with the Guide

This skill implements the read-only triage flow described in:
- **Section 6.17** (GKE MCP in Action) — Phase 1 triage and Phase 2 plan presentation
- **Section 3.16.3** (Segmented Endpoints) — endpoint discipline
- **Section 8.x** (Observability) — query_range patterns
