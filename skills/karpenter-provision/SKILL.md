---
name: karpenter-provision
description: Generate optimized Karpenter NodePool and EC2NodeClass configurations based on workload requirements. Handles Spot strategies, disruption budgets, instance diversity, and cost optimization.
---

# /karpenter-provision

## Purpose
Generate production-ready Karpenter configurations (NodePool + EC2NodeClass) optimized for cost, reliability, and the specific workload characteristics.

## Requirement Gathering

Ask the user for these details (if not already provided):

1. **Workload type**: stateless API, stateful (database/cache), batch/CI, GPU/ML, mixed
2. **Resources per pod**: typical vCPU and memory requests
3. **Capacity type**: on-demand only, spot only, or mixed (specify ratio)
4. **Monthly budget target**: helps size limits appropriately
5. **Region and AZs**: for subnet and zone configuration
6. **EKS version and Karpenter version**: for API compatibility
7. **Special requirements**: GPU, ARM64, high-memory, Windows, etc.

## Generation Rules

### Instance Type Selection
- **Stateless APIs**: c6i, c7g, m6i, m7g (compute/general purpose, good price-performance)
- **Memory-intensive**: r6i, r7g, r6a (memory optimized)
- **Batch/CI**: c6i, c6a, c7g, c7a, m6i, m6a, m7g (maximize diversity for Spot)
- **GPU**: p4d, p5, g5, g6 (match GPU type to workload: training vs inference)
- **ARM64 preferred**: Include Graviton variants (c7g, m7g, r7g) — 20-40% cheaper

### Instance Size Selection
- Match to pod resource requests: if pods need 2 vCPU/4GB, use large to 2xlarge
- Avoid oversized instances (4xlarge+) unless pods are large or bin-packing is critical
- Include at least 3 sizes for flexibility

### Spot Strategy
- **Minimum 15 instance types** for Spot-to-Spot consolidation
- Always include on-demand fallback for mixed strategies
- Use `weight` field: Spot NodePool weight=100, On-Demand weight=10 (fallback)
- Configure interruption handling (SQS + EventBridge)

### Disruption Policy
- Production: `consolidateAfter: 60s`, budgets: `nodes: "20%"`
- Batch: `consolidateAfter: 30s`, budgets: `nodes: "40%"`
- Add peak-hours protection budget for production
- Use `WhenEmptyOrUnderutilized` (default, recommended for most cases)

### Limits
- Set based on budget (rough formula: $0.04/vCPU-hour on-demand, $0.015 spot)
- Include both `cpu` and `memory` limits
- Leave 20% headroom above expected peak

## Output

Generate complete YAML files:

1. **NodePool(s)** with:
   - Instance family and size requirements
   - Capacity type (on-demand/spot)
   - AZ requirements
   - Labels and taints (for workload isolation)
   - Disruption policy with budgets
   - Resource limits
   - Weight (priority)
   - expireAfter (TTL for node rotation)

2. **EC2NodeClass** with:
   - amiSelectorTerms (alias for EKS-optimized AMI)
   - subnetSelectorTerms (tag-based discovery)
   - securityGroupSelectorTerms (tag-based discovery)
   - instanceProfile
   - blockDeviceMappings (root volume sizing)

3. **Supporting resources**:
   - PodDisruptionBudget for the primary workload
   - Recommended Prometheus ServiceMonitor config for Karpenter

## Validation Checklist

Before presenting the configuration, verify:

- [ ] Instance type diversity: ≥15 types for Spot, ≥6 for On-Demand
- [ ] All 3 AZs included for HA (if multi-AZ requested)
- [ ] Resource limits align with budget target
- [ ] consolidateAfter is appropriate (not 0s in production)
- [ ] Peak-hours budget protection included for production workloads
- [ ] Taints configured for workload isolation (if multiple NodePools)
- [ ] expireAfter set for node rotation (720h prod, 168h batch recommended)
- [ ] amiSelectorTerms uses alias (not custom AMI) unless specifically required
- [ ] No launch template references (not supported in v1 API)

## Examples

Common configurations the skill should handle:

- "Provision for a microservices platform with 50 stateless APIs"
- "Set up Karpenter for ML training workloads with p5.48xlarge GPUs"
- "Configure Spot-only NodePool for CI/CD runners"
- "Mixed strategy: critical payment service on On-Demand, everything else on Spot"
- "ARM64-first strategy with x86 fallback for cost optimization"
