---
name: gitops-promote
description: Promotes a service between environments via PR, delegating to the gitops-promoter subagent. Usage: /gitops-promote <service> <source-env> <target-env>
---

Delegate to the `gitops-promoter` subagent the promotion of $1 from $2
to $3, following the 6-step flow defined in that agent
(evidence → version → change → validation → PR → stop).

Before delegating:

1. Confirm that $3 is the next environment in the pipeline
   (dev → staging → production). Never skip environments.
2. If $3 is production, display the team's pre-production checklist
   (branch protection active, 2 approvers required, rollback tested)
   and ask for the operator's explicit confirmation before proceeding.
3. At the end, post the created PR's link and NOTHING else: the merge
   is human.

Requires: the `gitops-promoter` subagent installed in
`.claude/agents/gitops-promoter.md` (available in this repository
under `subagents/`).
