#!/bin/bash
# PreToolUse hook (matcher: Bash) — blocks cluster/IAM/git-history writes
# from any agent in a security-auditing repository.
#
# NOTE: this hook is the LAST layer, not the first. Pattern-matching a
# shell command can be bypassed (command chaining, variables, aliases,
# scripts). The primary boundaries are the permissions deny-list in
# .claude/settings.json and cloud-side IAM (a plan-only/read-only role).
# Treat this as a tripwire, not a wall.
#
# Register in .claude/settings.json:
#   "hooks": { "PreToolUse": [ { "matcher": "Bash",
#     "hooks": [ { "type": "command", "command": ".claude/hooks/block-security-writes.sh" } ] } ] }

INPUT=$(cat)

# Fail closed: if we cannot parse the command, we block rather than allow.
if ! command -v jq >/dev/null 2>&1; then
  echo "block-security-writes: jq not found; blocking by default (fail-closed)." >&2
  exit 2
fi

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
if [ -z "$COMMAND" ]; then
  echo "block-security-writes: could not parse tool input; blocking by default (fail-closed)." >&2
  exit 2
fi

# Case-insensitive; tolerates flags between the binary and the verb.
DENY='kubectl[^|&;]*[[:space:]](apply|delete|patch|edit|replace|scale|drain|cordon|taint)([[:space:]]|$)'
DENY="$DENY|aws[^|&;]*[[:space:]]iam[[:space:]][^|&;]*[[:space:]]?(delete|put|attach|detach|create|update|add|remove|tag|untag)-"
DENY="$DENY|git[^|&;]*[[:space:]]push[^|&;]*([[:space:]]-f([[:space:]]|$)|--force)"

if printf '%s' "$COMMAND" | grep -qiE "$DENY"; then
  # exit 2 blocks the call; the reason on stderr goes back to the agent
  echo "Write action blocked (rules/k8s-readonly-ops.md). Remediation is born as a PR via a gated executor." >&2
  exit 2
fi
exit 0
