# CLAUDE.md - Incident Response Agent Teams Template

Use this template to add Agent Teams configuration for incident response and war room automation. Copy and merge into your infrastructure project's `CLAUDE.md`.

> Requires: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json`

---

## Incident Response with Agent Teams

### When to Use Agent Teams for Incidents
- P1/P2 incidents affecting revenue or user experience
- Multiple data sources need correlation (logs + metrics + deploys)
- Time-critical investigation (every minute counts)

### Standard War Room Structure
Always create teams with these roles:

**1. incident-commander (LEAD)**
- Creates task list, delegates investigation
- Uses DELEGATE MODE (never investigates directly)
- Consolidates RCA when all tasks complete
- Recommends actions but NEVER executes

**2. logs-investigator**
- Searches: Elasticsearch, CloudWatch, Loki
- Reports: error type, first occurrence, frequency
- Messages metrics-analyzer with temporal findings

**3. metrics-analyzer**
- Queries: Prometheus, Grafana, Datadog
- Reports: anomaly start time, normal vs current values
- Correlates with findings from other teammates

**4. deploy-auditor**
- Checks: ArgoCD, Git log, merged PRs, config changes
- Reports: what changed, when, who approved, diff summary
- Broadcasts to all if deployment correlation found

### Task Dependencies
- Tasks 1-3 (investigation): NO dependencies, run in parallel
- Task 4 (consolidation): BLOCKED BY tasks 1-3

### Communication Rules
- Use MESSAGE for targeted findings (e.g., logs -> metrics)
- Use BROADCAST only for critical discoveries affecting all
- ALL findings MUST include UTC timestamps
- Confidence levels: High (>80%), Medium (50-80%), Low (<50%)

### Safety Rules
- **NEVER** execute remediation automatically
- **NEVER** modify production configuration
- **NEVER** access systems without proper credentials
- Always recommend actions and wait for human approval
- Include rollback command in every recommendation

### Report Format
Final RCA report MUST include:
1. Timeline of events (UTC)
2. Root cause with confidence level
3. Contributing factors
4. Evidence from each investigation stream
5. Recommended remediation steps
6. Rollback command (if applicable)
7. Prevention recommendations

### Example Prompt
```
P1 INCIDENT: [service-name] returning 500 errors, [X]% error rate.
Started approximately [TIME] UTC.

Create a war room with Agent Teams:
1. incident-commander (LEAD): Coordinate investigation, consolidate RCA
2. logs-investigator: Search application and infrastructure logs for errors since [TIME]
3. metrics-analyzer: Check CPU, memory, latency, error rate, connection pool metrics
4. deploy-auditor: Check all deployments, PRs merged, and config changes in last 2 hours

Rules:
- Teammates MUST message each other when they find something relevant
- Commander uses DELEGATE MODE only (do NOT investigate directly)
- ALL timestamps in UTC
- NEVER execute any remediation - recommend only
```

### Best Practices
1. **Force delegate mode**: Explicitly tell the lead to use Shift+Tab delegate mode, otherwise it tends to investigate alone
2. **Require cross-team messaging**: Say "Teammates MUST message each other when they find something relevant" in the prompt
3. **Size tasks appropriately**: Each agent should have 1 clear, independent investigation area
4. **Set time boundaries**: Always specify the investigation time window (e.g., "last 2 hours")
5. **Save the prompt**: Agent Teams sessions cannot be resumed if the lead goes down — keep the prompt saved for quick re-launch

### Limitations
- Agent Teams is experimental (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- Task status may lag between teammates
- No session resume if the lead process stops
- All teammates inherit the lead's permissions — be careful with `--dangerously-skip-permissions`
- Token-intensive: validate final report before acting on recommendations
