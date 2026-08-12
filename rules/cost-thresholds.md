# Cost Thresholds

Drop this file into `.claude/rules/cost-thresholds.md` and adjust the
numbers to your organization (record them in an ADR so they have an
owner and a review cadence).

- PR delta > $500/month (Infracost): FinOps approval required.
- Rightsizing: minimum 30% margin over P95 utilization; NEVER reduce
  production limits without a canary.
- Anomaly > 20% day-over-day: alert the team tag's owner;
  > 50%: page on-call.
- Resource deletion: ALWAYS via a gated executor (snapshot + PR),
  never direct (a PreToolUse hook blocks it).
