---
description: "Rapid production incident diagnosis with structured RCA output"
---

# /incident-debug

## Data Collection
1. Query recent metrics (if Prometheus/CloudWatch MCP available)
2. Correlate: recent deployments vs incident start time
3. Check active alerts and their trigger times
4. Collect error logs from the last 30 minutes
5. If tracing available: identify slowest spans

## Analysis Checklist
- [ ] Recent deployment caused the incident? (timing correlation)
- [ ] Error rate spike: which endpoint/service?
- [ ] Latency: P50/P95/P99 vs baseline (last 7 days average)
- [ ] Resources: CPU/Memory/Disk pressure on any node?
- [ ] Dependencies: downstream service with issues?
- [ ] DNS/Network: resolution or connectivity problems?
- [ ] Database: connection pool exhaustion? slow queries? locks?
- [ ] Rate limiting: upstream throttling or quota exceeded?

## Output Format
Return structured incident report:

1. **Severity**: SEV1/SEV2/SEV3/SEV4 (with justification)
   - SEV1: Service fully down, revenue impact
   - SEV2: Degraded performance, partial impact
   - SEV3: Minor feature broken, workaround exists
   - SEV4: Cosmetic/low-priority issue

2. **Timeline**: Sequence of events with timestamps
   - First anomaly detected
   - Alert triggered
   - Impact started
   - Current status

3. **Root Cause Hypothesis**: Most likely cause with evidence
   - Confidence level (HIGH/MEDIUM/LOW)
   - Supporting data points
   - Alternative hypotheses if confidence < 70%

4. **Mitigation**: Immediate action recommended
   - Rollback? Scale up? Feature flag? DNS failover?
   - Estimated time to resolution
   - Risk of the mitigation itself

5. **Next Steps**: Additional investigation needed
   - What data is missing?
   - Who to page/escalate to?
   - Monitoring to add post-incident
