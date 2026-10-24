---
name: model-migration-audit
description: Inventory every place a repo pins or configures a Claude model (API code, CI, Helm values, env vars, Claude Code settings, agent and skill frontmatter) and flag what breaks on the current generation (Claude Opus 5.5, Fable 5.1, Sonnet 5.5). Read-only. Use before moving to a new Claude model.
allowed-tools: Read Grep Glob
disable-model-invocation: true
model: opus
effort: high
---

# /model-migration-audit

Read-only audit. **Never edit files.** The output is a report that a human turns
into PRs (API code fixes can then go through `/claude-api migrate`, one repo per PR).

Target generation used by this checklist (verify against
https://platform.claude.com/docs/en/about-claude/models/overview before running):
`claude-opus-5-5` (default effort `medium`), `claude-fable-5-1`, `claude-sonnet-5-5`,
`claude-haiku-5-5`.

## 1. Model pins and aliases

Search the whole repository, including CI and deploy config
(`.github/`, `.gitlab-ci.yml`, `Jenkinsfile`, `helm/`, `charts/`, `k8s/`, `terraform/`, `*.env*`):

- Model IDs: `claude-(opus|sonnet|haiku|fable|mythos)-[0-9]`, dated IDs such as
  `claude-sonnet-4-20250514`, Bedrock IDs (`anthropic.claude-`, `us.anthropic.claude-`,
  `global.anthropic.claude-`), application inference profile ARNs
- Env vars: `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`,
  `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`,
  `ANTHROPIC_DEFAULT_FABLE_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`, `CLAUDE_CODE_EFFORT_LEVEL`
- Claude Code settings (`.claude/settings*.json`, `managed-settings.json`): `model`,
  `availableModels`, `deniedModels`, `availableModelsMatch`, `modelOverrides`,
  `effortLevel`, `modelSettings`, `maxEffortLevel`, `fallbackModel`
- Frontmatter in `.claude/agents/*.md` and `**/SKILL.md`: `model:` and `effort:`
- CLI calls: `claude -p ... --model`, `--effort`, `--fallback-model`

Flag:
- **HIGH** an alias (`opus`, `sonnet`, `haiku`, `best`) used in CI or in a gating job
  (aliases resolve differently per provider and change over time)
- **HIGH** `sonnet` alias on Bedrock or Google Cloud without `ANTHROPIC_DEFAULT_SONNET_MODEL`
  (resolves to an older Sonnet there)
- **MEDIUM** a pinned ID older than the current generation
- **MEDIUM** a CI job that sets no explicit effort (the Opus 5.5 default is `medium`)
- **MEDIUM** `--fallback-model` on a job that decides merges or deploys

## 2. API parameters the current models reject (400)

Search code that calls the Messages API (Python, TypeScript, Go, Java, curl, `ant`):

| Pattern | Why it breaks | Fix |
|---|---|---|
| `"type": "disabled"` or `budget_tokens` inside `thinking` | Opus 5.5 and Fable 5.1 reject disabled thinking and manual budgets | Remove `thinking` (or `{"type": "adaptive"}`) and set `output_config.effort` |
| `tool_choice` with `"any"` or `"tool"` | Forced tool use is not supported on Opus 5.5, Fable 5.1, Sonnet 5.5 | `tool_choice: {"type": "auto"}` + `"strict": true` on the tool, or structured outputs |
| `temperature`, `top_p`, `top_k` | Rejected on Opus 5.5 and Sonnet 5.5 | Remove; steer with prompts or structured outputs |
| `messages` ending with an `assistant` turn (prefill) | Rejected on Opus 5.5 | Structured outputs or system instructions |
| `computer_20251124` | Rejected on Opus 5.5 on the Claude API and Google Cloud (Google managed) | `computer_toolset_20260801` |

## 3. Response handling

- `content[0]`, `.content[0].text`, `response.content[0]`: any response can start with
  `thinking` blocks. Select blocks by `type`.
- Code that parses the `thinking` field as data: it is display text and is empty at the
  default `display: "omitted"`.
- UIs that stream text between tool calls: that text now arrives in `thinking` blocks;
  needs `thinking.display` set to `"updates"` (beta) or `"summarized"`.
- No handling of `stop_reason == "refusal"`: in a gate, a refusal must fail closed
  (route to a human), never pass.
- Code that edits the system prompt, tools or earlier turns mid-conversation: thinking
  blocks are tied to the conversation; prefer append-only conversations.

## 4. Claude Code instructions

Recommend running `/doctor prompt-audit` (Claude Code v2.1.283+) on the repo for CLAUDE.md,
skills, agents and commands written for older models. Do not duplicate its work here.

## Output

One Markdown table, sorted by severity, then a short summary:

| File | Line | Finding | Severity | Suggested fix |
|---|---|---|---|---|

Summary must include: number of repos/files scanned, count per severity, which items
`/claude-api migrate` can fix, and which need a platform decision (managed settings,
Bedrock pins, CI gates). See `references/managed-settings.example.json` for a starting
policy.
