# AWS Guardrails

Drop this file into `.claude/rules/aws-guardrails.md` in your
infrastructure repository. Pair it with a plan-only IAM role for the
agent (the hard guardrail) and cite your ADRs so answers trace back to
recorded decisions.

- NEVER apply/deploy in production: the plan-only role guarantees it,
  this rule prevents the attempt.
- Every infra change is born as plan + PR; apply is a human with MFA or
  a CI step with approval.
- Workspace production = read-only. No "just this once" exceptions.
- Allowed MCPs: the ones in this repo's `settings.json`. Do not suggest
  installing others.
- Every new-resource recommendation includes the required tags
  (team, env, cost-center, service).
