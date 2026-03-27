---
description: "Cloud cost review and optimization with actionable savings"
---

# /cost-review

## Data Collection
1. Query cost data for the current and previous month
2. If Cost Explorer MCP available: pull cost breakdown by service
3. If CloudWatch MCP available: pull resource utilization metrics
4. Identify billing account structure (single vs multi-account)

## Analysis Checklist
- [ ] Top 10 most expensive resources (by monthly cost)
- [ ] Idle resources: running >7 days with no/minimal traffic
- [ ] Oversized instances: CPU/memory utilization <30% average
- [ ] Missing Reserved Instances / Savings Plans coverage
- [ ] Storage: unattached EBS volumes, old snapshots (>90 days)
- [ ] Data transfer: unnecessary cross-AZ or cross-region traffic
- [ ] NAT Gateway costs vs VPC Endpoints (S3, DynamoDB, ECR)
- [ ] Dev/staging environments running outside business hours
- [ ] Unused Elastic IPs (charged when not attached)
- [ ] Old AMIs and unused ECR images consuming storage

## Output Format
Return structured cost review:

1. **Monthly Spend Summary**
   - Current month spend (to date)
   - Projected end-of-month total
   - Month-over-month change (% and $)
   - Top 5 services by cost

2. **Quick Wins** (immediate savings, <1 hour effort)
   - Idle resources to terminate
   - Unattached volumes to delete
   - Old snapshots to clean up
   - Estimated savings: $X/month

3. **Medium-Term Optimizations** (1-2 weeks effort)
   - RI/Savings Plans recommendations with break-even analysis
   - Rightsizing recommendations with utilization data
   - Architecture changes (NAT Gateway to VPC Endpoints)
   - Estimated savings: $X/month

4. **Long-Term Strategy** (1-3 months effort)
   - Spot instance adoption for fault-tolerant workloads
   - Graviton migration for compute-heavy services
   - Storage tiering (S3 Intelligent-Tiering, EBS gp3)
   - Estimated savings: $X/month

5. **Total Estimated Savings**: $X/month
   - Confidence level for each category
   - Implementation priority (effort vs impact matrix)
