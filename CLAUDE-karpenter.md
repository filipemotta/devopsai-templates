# CLAUDE.md - Karpenter Management Template

Use this template as the base CLAUDE.md for projects that manage Karpenter on EKS. Copy to your project's root directory and customize the values.

---

# CLAUDE.md - Karpenter Cluster Management

## Cluster Context

- **Cluster Name**: [CLUSTER_NAME]
- **EKS Version**: [EKS_VERSION]
- **Karpenter Version**: [KARPENTER_VERSION]
- **Region**: [REGION]
- **Account ID**: [AWS_ACCOUNT_ID]
- **Environment**: [production / staging / dev]

## NodePools

- `production`: On-Demand, [INSTANCE_FAMILIES], production workloads
  - Limits: [CPU] CPU, [MEMORY] memory
  - consolidateAfter: 60s
  - Peak protection: 9h-11h weekdays (no underutilized consolidation)
- `batch`: Spot + On-Demand fallback, [INSTANCE_FAMILIES], batch jobs and CI
  - Limits: [CPU] CPU, [MEMORY] memory
  - consolidateAfter: 30s
- `[ADDITIONAL_POOLS]`: Add as needed (GPU, ARM64, etc.)

## Safety Rules

### NEVER (require explicit human approval)
- Modify NodePool `limits` — can cause capacity starvation or cost explosion
- Delete EC2NodeClass in production — orphans all nodes using it
- Set `consolidateAfter` below 10s in production — causes thrashing
- Remove peak-hours disruption budget — protects against consolidation during traffic spikes
- Apply `do-not-disrupt: "false"` to stateful workloads without verifying PDBs first
- Change `amiSelectorTerms` alias in production without testing in staging first

### ALWAYS
- Check `kubectl get nodeclaims` before and after any NodePool changes
- Verify PDBs exist for critical deployments before enabling consolidation
- Use `kubectl diff` before applying NodePool/EC2NodeClass changes
- Confirm current NodePool utilization vs limits before modifying limits
- Test AMI changes in non-production first via drift detection

### SAFE TO DO (no approval needed)
- Read operations: `kubectl get/describe nodeclaims/nodepools/ec2nodeclasses`
- Analyze logs: `kubectl logs -n karpenter`
- Check events: `kubectl get events`
- Query EC2 quotas: `aws service-quotas`
- Generate configuration suggestions (without applying)

## Debugging Steps

When troubleshooting Karpenter issues, follow this sequence:

1. **NodeClaim state**: `kubectl get nodeclaims -o wide`
2. **Pending pods**: `kubectl get pods --field-selector=status.phase=Pending -A`
3. **Recent events**: `kubectl get events --sort-by=.metadata.creationTimestamp | grep -i karpenter | tail -30`
4. **Controller logs**: `kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=200`
5. **NodePool utilization**: `kubectl get nodepool -o yaml` (check status.resources vs spec.limits)
6. **EC2 quotas**: `aws service-quotas list-service-quotas --service-code ec2 --query 'Quotas[?contains(QuotaName,\`Running On-Demand\`)].{Name:QuotaName,Value:Value}'`
7. **PDB check**: `kubectl get pdb -A` (may block consolidation)

## Cost Targets

- **Monthly budget**: $[BUDGET]
- **Spot ratio target**: [PERCENTAGE]% for non-critical workloads
- **Alert threshold**: Notify if monthly projection exceeds $[ALERT_THRESHOLD]
- **Consolidation target**: Average node utilization >60%

## Interruption Handling

- **SQS Queue**: [QUEUE_NAME] (for Spot interruption, rebalance, scheduled changes)
- **EventBridge Rules**: Configured for EC2 Spot Interruption Warning, Instance Rebalance Recommendation, Scheduled Change
- **Graceful shutdown**: Pods have [SECONDS]s terminationGracePeriodSeconds

## Monitoring

- **Prometheus**: Karpenter metrics exposed at `:8080/metrics`
- **Key metrics**: `karpenter_nodepools_usage`, `karpenter_nodepools_limit`, `karpenter_nodes_total`
- **Grafana dashboards**: [DASHBOARD_URLS]
- **Alerts**: NodePool utilization >80%, Pending pods >5min, NodeClaim failures

## Upgrade Process

When upgrading Karpenter:
1. Check compatibility: [karpenter.sh/docs/upgrading](https://karpenter.sh/docs/upgrading/)
2. EKS 1.32 requires Karpenter >= v1.1.2
3. EKS 1.33 requires Karpenter >= v1.5.0
4. Always upgrade Karpenter BEFORE upgrading EKS control plane
5. Test in staging first, monitor for 24h before production
