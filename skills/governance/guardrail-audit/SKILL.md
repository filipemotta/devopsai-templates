---
name: guardrail-audit
description: Read-only audit of a repository's Claude Code guardrails. Finds policy hooks that fail open (no onFailure "block", exit 1 instead of exit 2, async PreToolUse, missing dependencies), hooks that a repo or local file can remove, and OTEL_* telemetry settings that are ignored or that turn audit signals off. Use before trusting hooks as security controls or before a compliance review.
allowed-tools: Read Grep Glob
disable-model-invocation: true
model: opus
effort: high
---

# /guardrail-audit

Read-only audit. **Never edit files.** The output is a findings table plus a suggested
diff that a human reviews and merges. Changes to managed policy go through the
organization's normal security review, never through this skill.

Verify the behavior below against the official docs before running, since it changes
between versions:
- https://code.claude.com/docs/en/hooks#block-the-action-when-a-hook-fails
- https://code.claude.com/docs/en/monitoring-usage#audit-security-events
- https://code.claude.com/docs/en/settings-reference#allowmanagedhooksonly

Baseline used by this checklist: Claude Code v2.1.307 or later (`onFailure` since
v2.1.295, `claude_code.safety_event` since v2.1.307).

## 1. Inventory the hooks

Read every place hooks can be registered in the repo:
- `.claude/settings.json`, `.claude/settings.local.json` (if committed by mistake, flag it)
- `.claude/agents/*.md` frontmatter (`hooks:`)
- Plugins vendored in the repo (`**/.claude-plugin/plugin.json`, `**/hooks/hooks.json`)
- Any `managed-settings.json` or `managed-settings.d/*.json` kept in the repo as source of truth

For each hook record: event, matcher, `type`, the script it runs, `timeout`, `async`,
`asyncRewake`, `onFailure`, and where it is defined.

Classify each hook as **policy** (exists to stop an action: deny, block, require approval)
or **convenience** (format, lint, notify, log). Read the script to decide; do not guess from
the name.

## 2. Findings for policy hooks

| Pattern | Severity | Why |
|---|---|---|
| `PreToolUse`/`PermissionRequest` policy hook without `"onFailure": "block"` | HIGH | A missing script, crash, timeout or invalid JSON lets the call through as a non-blocking error |
| Script blocks with `exit 1` | HIGH | Only `exit 2` (reason on stderr) or exit 0 with `hookSpecificOutput.permissionDecision: "deny"` blocks; exit 1 is non-blocking unless `onFailure` is `"block"` |
| Policy hook with `async: true` or `asyncRewake: true` | HIGH | Background hooks can't gate the call, and `onFailure` has no effect on them |
| Script depends on `jq`, `yq`, `node`, `python3` without a fail-closed check | MEDIUM | On a runner image without it, the hook fails; fail-closed only if `onFailure` is set or the script exits 2 |
| Shell-form command with `${CLAUDE_PROJECT_DIR}` unquoted | MEDIUM | Paths with spaces break the hook; prefer exec form (`command` + `args`) |
| Script prints an allow and starts a background process without redirecting its output | MEDIUM | Claude Code refuses "the suspect capture" and blocks, or a late deny is ignored |
| Policy guardrail only in project settings | MEDIUM | Anyone who merges to the repo can remove it, and `disableAllHooks: true` in a local settings file disables every non-managed hook. Recommend a force-enabled plugin from the internal marketplace or managed settings |
| `"onFailure": "block"` on a convenience hook | LOW | A broken formatter now stops every matching call; keep fail-closed for gates only |
| `onFailure` on `Stop`, `SubagentStop`, `TaskCompleted`, `TeammateIdle` | LOW | No effect on those events; remove to avoid false confidence |

## 3. Telemetry settings

Search `.claude/settings*.json`, CI workflows (`.github/workflows/`, `.gitlab-ci.yml`) and
deploy config for `CLAUDE_CODE_ENABLE_TELEMETRY` and `OTEL_*`:

- **MEDIUM** exporter, endpoint or header variables in a repo's `.claude/settings.json` or
  `.claude/settings.local.json`: Claude Code ignores them there. Telemetry must come from
  managed settings, the user's shell or `~/.claude/settings.json`, or the CI job `env`.
- **HIGH** `OTEL_LOGS_EXPORTER` or `OTEL_METRICS_EXPORTER` set to `none` in repo settings:
  a repository can turn a signal off unless managed policy sets the selector.
- **HIGH** `OTEL_LOG_RAW_API_BODIES` anywhere near a SIEM endpoint: it exports whole
  conversations.
- **MEDIUM** `OTEL_LOG_TOOL_DETAILS=1` without a note that the collector is approved to hold
  command text and tool input.
- **MEDIUM** CI jobs that run `claude -p` without `--permission-prompts none` (v2.1.259+):
  prompt refusals then appear only as `tool_decision` rejects with no `safety_event`.
- **LOW** CI jobs on Bedrock, Google Cloud, Foundry or an API key without
  `OTEL_RESOURCE_ATTRIBUTES` carrying an identity (`enduser.id=...`): events carry only an
  anonymous `user.id`.

If the repo holds the organization's managed settings, also check:
- `requiredMinimumVersion` is at least `2.1.307`
- `OTEL_LOGS_EXPORTER` and the OTLP endpoint/headers are set there (this locks the destination)
- `OTEL_LOG_MANAGED_SETTINGS` is `"1"` so `managed_settings_resolved` carries a policy digest

## 4. Proof of fail-closed

For each HIGH finding on a policy hook, include the manual test in the report (do not run it):
1. Move the hook script away.
2. Ask Claude Code to run `ls`.
3. Expected with `onFailure: "block"`: the call is blocked and the error contains
   `failed; blocking because onFailure is "block"`. Without it, `ls` runs.
4. Restore the script.

## Output

One Markdown table sorted by severity, then the suggested diff, then a short summary:

| File | Hook / setting | Finding | Severity | Suggested fix |
|---|---|---|---|---|

The summary lists: hooks found (policy vs convenience), count per severity, what needs a
platform decision (moving a hook to a force-enabled plugin or managed settings,
`allowManagedHooksOnly`), and the detections the SIEM should run. See
`references/managed-settings.audit.example.json` and `references/otel-collector-audit.yaml`.
