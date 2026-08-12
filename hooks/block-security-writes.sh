#!/bin/bash
# PreToolUse hook (matcher: Bash) — blocks cluster/IAM/git-history writes
# from any agent in a security-auditing repository.
# Register in .claude/settings.json:
#   "hooks": { "PreToolUse": [ { "matcher": "Bash",
#     "hooks": [ { "type": "command", "command": ".claude/hooks/block-security-writes.sh" } ] } ] }

COMMAND=$(jq -r '.tool_input.command // ""')

if echo "$COMMAND" | grep -qE 'kubectl (apply|delete|patch|edit)|aws iam (delete|put|attach|detach|create)|git push --force'; then
  # exit 2 blocks the call; the reason on stderr goes back to the agent
  echo "Write action blocked (rules/k8s-readonly-ops.md). Remediation is born as a PR via a gated executor." >&2
  exit 2
fi
exit 0
