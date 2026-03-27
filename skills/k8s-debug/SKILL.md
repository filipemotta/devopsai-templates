---
name: k8s-debug
description: Automatically diagnose Kubernetes cluster and application issues. Collects node status, unhealthy pods, events, and resource usage, then returns a structured report with severity, evidence, and remediation steps.
---

# /k8s-debug

## Purpose
Automate Kubernetes cluster troubleshooting by collecting cluster state from multiple sources, analyzing it against known failure patterns, and returning a structured diagnostic report.

## Data Collection (run sequentially)

```bash
# 1. Node status and versions
kubectl get nodes -o wide

# 2. Non-healthy pods across all namespaces
kubectl get pods -A | grep -v Running | grep -v Completed

# 3. Recent events sorted by time
kubectl get events --sort-by=.metadata.creationTimestamp -A | tail -30

# 4. Node resource usage (requires metrics-server)
kubectl top nodes

# 5. Top memory-consuming pods
kubectl top pods -A --sort-by=memory | head -20
```

## Analysis Checklist

After collecting data, check each item:

### Node Issues
- [ ] Nodes in `NotReady` state -> check kubelet logs, network connectivity
- [ ] Node resource pressure (`MemoryPressure`, `DiskPressure`, `PIDPressure`) -> identify pods without limits
- [ ] Kubelet version skew between nodes -> should be within 1 minor version
- [ ] Unschedulable nodes (cordoned) -> check if intentional or leftover from maintenance
- [ ] Node conditions with `Unknown` status -> kubelet communication issues

### Pod Issues
- [ ] `CrashLoopBackOff` -> check logs (`kubectl logs <pod> --previous`), resource limits, liveness probes
- [ ] `ImagePullBackOff` -> registry auth, image tag existence, imagePullSecrets
- [ ] `OOMKilled` (Exit Code 137) -> memory limits too low, check actual usage vs limits
- [ ] `Pending` -> insufficient resources, node affinity rules, taints/tolerations mismatch
- [ ] `Evicted` -> node resource pressure, ephemeral storage limits exceeded
- [ ] `CreateContainerConfigError` -> missing ConfigMaps or Secrets referenced in spec

### Network Issues
- [ ] Services with no endpoints -> selector mismatch or no matching pods
- [ ] DNS resolution failures -> check CoreDNS pods health and logs
- [ ] NetworkPolicies blocking traffic -> check default deny policies

### Resource Issues
- [ ] Pods without resource requests/limits -> risk of noisy neighbor problems
- [ ] Over-provisioned pods (request >> actual usage) -> wasting cluster capacity
- [ ] PVCs in Pending state -> no matching StorageClass or insufficient capacity

## Output Format

Return a structured report:

```
================================================================
  KUBERNETES CLUSTER DIAGNOSTIC REPORT
  Cluster: [cluster-name] | Time: [timestamp]
================================================================

STATUS: [Healthy | Warning | Critical]

--- ISSUES FOUND ------------------------------------------------

[CRITICAL] Issue title
  Evidence: What was found in logs/events/status
  Impact: What this causes for the application/cluster
  Fix: Specific kubectl command(s) or YAML patch to resolve

[WARNING] Issue title
  Evidence: ...
  Impact: ...
  Fix: ...

[INFO] Issue title
  Evidence: ...
  Suggestion: ...

--- RESOURCE SUMMARY -------------------------------------------

Nodes: X total | Y Ready | Z with conditions
CPU:   X/Y cores (Z%) allocated | W cores (V%) actual usage
Memory: X/Y Gi (Z%) allocated | W Gi (V%) actual usage
Pods:  X/Y (Z% of cluster capacity)
```

## Tips
- Run this skill as a daily health check or when alerts fire
- Pair with `/k8s-review` for pre-deploy manifest validation
- For Karpenter-specific issues, use `/karpenter-debug` instead
- If metrics-server is not installed, steps 4 and 5 will be skipped automatically
