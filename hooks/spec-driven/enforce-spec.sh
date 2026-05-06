#!/usr/bin/env bash
# enforce-spec — PreToolUse hook for Spec-Driven Development
#
# Blocks Edit/Write/MultiEdit operations on files NOT listed in the active
# task's tasks.md. Allows only what /spec-execute has authorized via env vars.
#
# Bypass: set CLAUDE_SPEC_BYPASS=1 (logged for audit).
#
# Register in .claude/settings.json:
#   {
#     "hooks": {
#       "PreToolUse": [{
#         "matcher": "Edit|Write|MultiEdit",
#         "hooks": [{ "type": "command", "command": ".claude/hooks/enforce-spec.sh" }]
#       }]
#     }
#   }

set -euo pipefail

# Read tool input from stdin (JSON from Claude Code)
INPUT=$(cat)
TARGET_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# No file path? allow (e.g., notebooks, MCP tools)
if [ -z "$TARGET_FILE" ]; then
  exit 0
fi

# Bypass mode — log and allow
if [ "${CLAUDE_SPEC_BYPASS:-0}" = "1" ]; then
  echo "$(date -u +%FT%TZ) BYPASS edit: $TARGET_FILE" >> .claude/spec-bypass.log
  exit 0
fi

# Always allow: spec files themselves, steering, agents, skills, hooks
case "$TARGET_FILE" in
  *.claude/specs/*|*.claude/steering/*|*.claude/agents/*|*.claude/skills/*|*.claude/hooks/*|*.claude/settings*.json)
    exit 0
    ;;
esac

# Always allow: docs/markdown outside of code paths
case "$TARGET_FILE" in
  *.md|*.txt|*README*|*CHANGELOG*)
    # Only allow if not a spec file in disguise
    exit 0
    ;;
esac

# Spec mode active? check task scope
ACTIVE_SPEC="${CLAUDE_SPEC_ACTIVE:-}"
ACTIVE_TASK="${CLAUDE_SPEC_TASK:-}"

if [ -z "$ACTIVE_SPEC" ]; then
  # No active spec — block writes outside .claude/
  cat <<EOF >&2
{
  "continue": false,
  "permissionDecision": "deny",
  "stopReason": "No active spec. Run /spec-execute <feature-name> to begin spec-driven implementation, or set CLAUDE_SPEC_BYPASS=1 for a one-off emergency change (logged)."
}
EOF
  exit 2
fi

TASKS_FILE=".claude/specs/$ACTIVE_SPEC/tasks.md"

if [ ! -f "$TASKS_FILE" ]; then
  cat <<EOF >&2
{
  "continue": false,
  "permissionDecision": "deny",
  "stopReason": "Active spec '$ACTIVE_SPEC' has no tasks.md. Cannot validate scope."
}
EOF
  exit 2
fi

# Extract allowed file paths from the current task
# Tasks reference paths in lines like:
#   Files: terraform/environments/prod/vpc/main.tf
# or as inline code: `terraform/.../main.tf`
if [ -n "$ACTIVE_TASK" ]; then
  # Extract paths under the specific task heading
  ALLOWED=$(awk -v task="$ACTIVE_TASK" '
    $0 ~ "\\*\\*"task"\\*\\*" { in_task = 1; next }
    in_task && /^- \[/ { in_task = 0 }
    in_task && /Files:|files:/ { gsub(/.*[Ff]iles: */, ""); print }
    in_task && /`[^`]+`/ { while (match($0, /`[^`]+`/)) { print substr($0, RSTART+1, RLENGTH-2); $0 = substr($0, RSTART+RLENGTH) } }
  ' "$TASKS_FILE")
else
  # No specific task — allow any file mentioned in tasks.md
  ALLOWED=$(grep -oP '(?<=Files: )[^ ]+|(?<=`)[^`]+\.\w+(?=`)' "$TASKS_FILE" || true)
fi

# Match TARGET_FILE against allowed paths (substring match for flexibility)
for path in $ALLOWED; do
  if echo "$TARGET_FILE" | grep -qF "$path"; then
    exit 0
  fi
done

# Not in scope — block
cat <<EOF >&2
{
  "continue": false,
  "permissionDecision": "deny",
  "stopReason": "File '$TARGET_FILE' is not in the scope of active task '$ACTIVE_TASK' (spec: $ACTIVE_SPEC). Allowed paths from tasks.md: $(echo $ALLOWED | tr '\n' ', '). To extend task scope: edit tasks.md and re-approve. To bypass for emergency: CLAUDE_SPEC_BYPASS=1 (logged)."
}
EOF
exit 2
