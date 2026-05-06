# CLAUDE.md - Spec-Driven Development Template

This project uses **Spec-Driven Development (SDD)** with Claude Code. Specifications are the source of truth; code is a build artifact derived from approved specs.

## Methodology

Every non-trivial feature follows the canonical workflow:

```
constitution → /spec-create → requirements.md → design.md → tasks.md → /spec-execute → verify
```

Each phase has a human approval gate. Do NOT skip phases. Do NOT generate code outside an approved `tasks.md`.

## When to Use SDD

**USE SDD when:**
- Change goes to production
- Multiple engineers need to agree on intent
- Compliance/audit requires written rationale (PCI, HIPAA, SOC2)
- Blast radius is large (infra, schema, public API)

**SKIP SDD when:**
- Incident response (MTTR > rigor)
- Hotfix (< 30 min change)
- Local exploration / spike
- Trivial refactor or typo fix

## File Structure

```
.claude/
├── steering/           # Constitution: persistent project context
│   ├── tech.md         # Languages, frameworks, conventions
│   ├── product.md      # Business domain rules
│   └── structure.md    # Directory layout, file conventions
├── specs/              # All feature specs (versioned in Git)
│   └── <feature-name>/
│       ├── requirements.md   # User stories + acceptance criteria (EARS)
│       ├── design.md         # Technical architecture
│       └── tasks.md          # Atomic implementation tasks
├── agents/             # Specialized subagents per phase
├── skills/             # Slash commands orchestrating the workflow
└── hooks/              # PreToolUse hooks enforcing spec compliance
```

## The Three Pillars

### 1. Contracts (the specs)
- **`steering/*.md`**: persistent constitution (rarely changes)
- **`requirements.md`**: WHAT to build, written in EARS format ("WHEN <event>, THE <system> SHALL <response>")
- **`design.md`**: HOW it'll be built, with architecture decisions and rationale
- **`tasks.md`**: discrete checkboxes, one task = one PR-sized change

### 2. Agents (specialized per phase)
- `requirements-agent`: extracts requirements interactively from natural-language input
- `design-agent`: proposes technical design respecting steering
- `tasks-agent`: breaks design into atomic, trackable tasks
- `implementation-agent`: writes code for ONE task at a time
- `spec-validator`: gates between phases (no advancing without explicit approval)

### 3. Runtime (Claude Code)
- **Slash commands**: `/spec-create`, `/spec-execute`, `/spec-status`, `/spec-validate`
- **Hooks**: `PreToolUse` hook blocks Edit/Write outside approved `tasks.md`
- **MCP servers**: queried by design-agent to validate technical decisions against current docs (Context7, Terraform Registry, etc.)

## Workflow Rules

1. **No code without spec.** Every implementation requires an approved `tasks.md`.
2. **No phase skipping.** Requirements → Design → Tasks → Implementation. Always.
3. **Specs are immutable per release.** Once `tasks.md` is approved, edits to upstream phases require explicit re-approval and may invalidate downstream phases.
4. **Drift = spec mismatch.** If runtime state diverges from spec, decide: fix code or amend spec. Never silent drift.
5. **Steering changes slowly.** Edits to `steering/*.md` require team consensus.

## Domain-Specific Applications

### Infrastructure as Code (Terraform)
- `requirements.md`: business need (e.g., "PCI-compliant VPC with NAT HA")
- `design.md`: module choice, CIDR plan, state strategy, tagging
- `tasks.md`: one task per `.tf` file or logical unit
- Validation: `terraform fmt && validate && plan` against spec

### Kubernetes
- `requirements.md`: SLA, tier, compliance, expected load
- `design.md`: replica strategy, resource sizing, network policy graph
- `tasks.md`: one per manifest (`deployment.yaml`, `networkpolicy.yaml`, `kyverno-policy.yaml`)
- Validation: `kubeval` + `kube-score` + `kyverno test`

### Observability (SLOs)
- `requirements.md`: business impact, stakeholders, tier
- `slo.md`: formal SLI definitions, SLO targets, error budget math
- `design.md`: PromQL queries, multi-window burn-rate alerts, dashboard mapping
- `tasks.md`: rules.yaml, alerts.yaml, dashboard.json, runbook.md
- Validation: `promtool check rules` + `promtool test rules`

## Available Slash Commands

- `/spec-create <feature>` — start a new spec, conducts requirements → design → tasks
- `/spec-execute <feature>` — implement next unchecked task in `tasks.md`
- `/spec-status [feature]` — show progress; if no arg, list all in-flight specs
- `/spec-validate <feature>` — re-validate that current state matches approved spec

## Hook: enforce-spec

Configured as `PreToolUse` matcher on `Edit|Write|MultiEdit`. Blocks tool execution if the target file path is not present in any approved `tasks.md` AND the current task is not in "execute" mode.

To bypass for emergencies (incident response): `CLAUDE_SPEC_BYPASS=1` env var. Logged for audit.

## Steering Files (Required Constitution)

You MUST maintain these files. They're the "constitution" — persistent context loaded into every spec phase:

- **`.claude/steering/tech.md`** — languages, framework versions, library choices, testing strategy
- **`.claude/steering/product.md`** — business domain, user types, key constraints
- **`.claude/steering/structure.md`** — directory conventions, naming patterns, file organization

Without steering files, agents lack context and produce generic, inconsistent specs.

## References

- Framework foundation: see Chapter 4.16 of [The DevOps AI Official Guide](https://devops-ai.tech)
- Terraform application: Chapter 5.16
- Kubernetes application: Chapter 6.16
- Observability application: Chapter 8.15
