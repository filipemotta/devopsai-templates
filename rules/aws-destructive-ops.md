# Destructive AWS Operations

Drop this file into `.claude/rules/aws-destructive-ops.md`. It is the
declarative half of a PreToolUse hook that blocks destructive
`call_aws` actions (the hook enforces; this rule explains, so the agent
plans correctly the first time).

- Actions prefixed `Delete*`, `Terminate*`, `Drop*`, `Stop*`,
  `Detach*`, `Disable*`, `Revoke*` NEVER leave the agent: the
  PreToolUse hook blocks them.
- If a task requires one of those actions, the output is the READY
  COMMAND for the human to paste in their own terminal, with the why
  and the blast radius.
- Deleting a resource with data (RDS, S3, EBS) additionally requires a
  confirmed snapshot/backup in the plan.
- Recurrence: if the same destructive request appears 2+ times, log it
  in `docs/aws-audit-log.md` and suggest safe automation via IaC.

Reference hook (blocks and returns the reason to the agent):

```bash
#!/usr/bin/env bash
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
[[ "$TOOL" != "mcp__aws-mcp__call_aws" ]] && exit 0

ACTION=$(echo "$INPUT" | jq -r '.tool_input.action // ""')
if [[ "$ACTION" =~ ^(Delete|Terminate|Drop|Stop|Detach|Disable|Revoke) ]]; then
  # exit 2 blocks the call; the reason on stderr goes back to the agent
  echo "Destructive action $ACTION blocked by hook (rules/aws-destructive-ops.md). Run it manually from a human terminal session." >&2
  exit 2
fi
exit 0
```
