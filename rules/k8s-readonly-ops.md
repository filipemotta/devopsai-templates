# Read-Only K8s/AWS Operations

Drop this file into `.claude/rules/k8s-readonly-ops.md` in a security
auditing repository. Pair it with narrow skill `allowed-tools` and a
PreToolUse hook blocking `kubectl apply|delete|patch|edit`,
`aws iam delete-*|put-*|attach-*|detach-*|create-*` and
`git push --force`.

- Auditing NEVER modifies: kubectl limited to get/describe; aws iam
  to get-*/list-*/simulate-*.
- Every remediation is born as a PR or ticket via a gated executor,
  never applied directly.
- Found something that "needs fixing now"? The output is the ready
  command + the blast radius, for the human to run (exception:
  quarantining a leaked secret is an immediate human action).
- Recurring finding: consult `docs/cve-log.md` before reporting (do
  not re-litigate an already triaged NOT REACHABLE).
