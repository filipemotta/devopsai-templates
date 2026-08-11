---
name: aws-audit
description: AWS account security audit via the iam-auditor subagent. Usage: /aws-audit [scope: iam | network | full]
---

Delegate the audit with scope $1 (default: full) to the `iam-auditor`
subagent.

1. Confirm the session uses read-only credentials. Credentials with
   write access? Stop and warn: an audit never runs with the power to
   change things.
2. At the end, the report goes to `docs/audits/YYYY-MM-DD.md` and
   new/recurring findings to `docs/aws-audit-log.md`.
3. For each CRITICAL, open (or propose) the correction PR via IaC.
   Never fix directly in the account... even with credentials that
   would allow it.

Requires: the `iam-auditor` subagent installed in
`.claude/agents/iam-auditor.md` (available in this repository under
`subagents/`).
