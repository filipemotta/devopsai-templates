# enforce-spec hook

PreToolUse hook that enforces Spec-Driven Development boundaries by blocking `Edit`/`Write`/`MultiEdit` operations on files outside the currently active task's scope.

## Installation

1. Copy `enforce-spec.sh` to `.claude/hooks/enforce-spec.sh`:
   ```bash
   mkdir -p .claude/hooks
   cp enforce-spec.sh .claude/hooks/enforce-spec.sh
   chmod +x .claude/hooks/enforce-spec.sh
   ```

2. Register in `.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Edit|Write|MultiEdit",
           "hooks": [
             {
               "type": "command",
               "command": ".claude/hooks/enforce-spec.sh"
             }
           ]
         }
       ]
     }
   }
   ```

3. Verify: `/hooks` (slash command) — should list `enforce-spec`.

## How it works

The `/spec-execute` skill exports two env vars before invoking `implementation-agent`:
- `CLAUDE_SPEC_ACTIVE=<feature-name>` — which spec is being executed
- `CLAUDE_SPEC_TASK=<task-id>` — which specific task is in scope

When the agent attempts to Edit/Write/MultiEdit:
1. Hook reads stdin JSON for `tool_input.file_path`
2. If file is in `.claude/` (specs, steering, agents, skills, hooks) → allow
3. If `CLAUDE_SPEC_BYPASS=1` → log to `.claude/spec-bypass.log` and allow
4. Otherwise: open `.claude/specs/<feature>/tasks.md` and parse allowed file paths from the active task
5. If target file is not in allowed list → block with structured error

## Bypass for emergencies

For incident response or hotfix when SDD overhead is unjustified:

```bash
CLAUDE_SPEC_BYPASS=1 claude "fix critical typo in payment-service config"
```

Bypasses are logged to `.claude/spec-bypass.log` for audit. Goal: keep bypasses below 10% of changes.

## Tuning

- The shell script uses substring matching on file paths. If your project has paths that overlap (e.g., `services/payment` and `services/payment-history`), tighten to glob/regex matching.
- For monorepos with deep paths, consider using a Python or Node version of this hook for more robust parsing.
- The hook always allows edits to `.md`, `.txt`, README, and CHANGELOG files. If your project keeps spec-relevant files in other extensions, adjust the case statement.

## Exit codes

- `0` — allow operation
- `2` — block operation (Claude Code reads stdout JSON for stopReason)

## See also

- Chapter 4.16 of [The DevOps AI Official Guide](https://devops-ai.tech) for the full Spec-Driven framework
- `/spec-create`, `/spec-execute`, `/spec-status`, `/spec-validate` slash commands
