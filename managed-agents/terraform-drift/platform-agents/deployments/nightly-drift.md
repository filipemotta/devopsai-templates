---
name: Nightly Terraform drift
agent: ../agents/tf-drift.md
environment_id: ../environments/drift-runner.yaml
vault_ids:
  - ../vaults/github-drift.yaml
resources:
  - path: ../memory_stores/drift-ledger.yaml   # the only resource type self-hosted accepts
    access: read_write
schedule:
  type: cron
  expression: "30 5 * * 1-5"    # 05:30 UTC, Mon-Fri; UTC avoids the DST window
  timezone: UTC
budget:
  type: limit
  max_list_cost:
    amount: "500"               # cents: US$ 5 per run, not cumulative
    currency: USD
---
Run the daily drift triage for acme/infra.
