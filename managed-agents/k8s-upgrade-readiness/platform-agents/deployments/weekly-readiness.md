---
name: Weekly upgrade readiness (prod-eu)
agent: ../agents/k8s-upgrade-readiness.md
environment_id: ../environments/readiness-runner.yaml
vault_ids:
  - ../vaults/github-readiness.yaml
resources:
  - path: ../memory_stores/readiness-ledger.yaml   # the only resource type self-hosted accepts
    access: read_write
schedule:
  type: cron
  expression: "0 6 * * 1"       # Mondays 06:00 UTC
  timezone: UTC
budget:
  type: limit
  max_list_cost:
    amount: "300"               # cents: US$ 3 per run, not cumulative
    currency: USD
---
Run the upgrade-readiness check for cluster prod-eu.
