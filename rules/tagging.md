# Tagging for Cost Attribution

Drop this file into `.claude/rules/tagging.md`. Pair it with an ADR
recording your tag taxonomy, CI enforcement, and AWS Tag Policies +
SCPs as the backstop.

- Every resource in generated or reviewed IaC includes the four keys:
  team, env, service, cost-center.
- team values come from the catalog in `docs/teams.yaml`; never
  invent one.
- A PR creating a resource without the required tags: BLOCKER in
  review.
- In Kubernetes, labels mirror the same keys (Kubecost/OpenCost
  aggregate by them).
