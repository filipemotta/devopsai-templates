---
name: spec-create
description: Start a new Spec-Driven feature — orchestrates requirements → design → tasks with human approval gates between phases
context: fork
allowed-tools: Read(*) Write(.claude/specs/**) Glob(*) Bash(ls .claude/**)
---

# /spec-create

> **Frontmatter notes**:
> - `context: fork` — runs in an isolated subagent context so prior conversation doesn't bias the spec phases
> - `allowed-tools` — restricted to reading any file, but writing only inside `.claude/specs/`. Prevents the skill from generating code outside the spec workflow.


Create a new feature spec following the canonical Spec-Driven Development workflow. Conducts the user through three phases — Requirements, Design, Tasks — with explicit approval between each.

## Usage

```
/spec-create <feature-name>
```

Example: `/spec-create payment-vpc-pci`

## Prerequisites

- `.claude/steering/` exists with at least `tech.md` (constitution)
- Subagents installed: `requirements-agent`, `design-agent`, `tasks-agent`, `spec-validator`
- Hook `enforce-spec` configured in `.claude/settings.json`

If any are missing, halt and tell the user what to set up first.

## Workflow

### Phase 0 — Setup
1. Validate `<feature-name>` is kebab-case, no spaces
2. Create directory `.claude/specs/<feature-name>/`
3. Read all files in `.claude/steering/` to load project constitution
4. Confirm with user: "Loaded steering: <list files>. Proceed?"

### Phase 1 — Requirements
1. Invoke `requirements-agent` subagent with the feature name and steering context
2. Subagent conducts a guided interview (compliance, constraints, user stories)
3. Output: `.claude/specs/<feature-name>/requirements.md` in EARS format
4. Show diff/preview to user
5. **GATE**: ask "Approve requirements? (yes / edit / cancel)"
   - `yes` → proceed to Phase 2
   - `edit` → user edits the file, then re-approve
   - `cancel` → halt, leave file as draft

### Phase 2 — Design
1. Invoke `design-agent` subagent with requirements.md + steering
2. Subagent proposes technical design (architecture, libraries, modules, providers, schema)
3. **For DevOps domains**:
   - IaC: choose Terraform module sources, state backend, naming
   - K8s: replica strategy, resource sizing, policies
   - Observability: PromQL queries, alert math, dashboard layout
4. design-agent SHOULD use Context7 MCP to validate library/version choices
5. Output: `.claude/specs/<feature-name>/design.md`
6. **GATE**: ask "Approve design? (yes / edit / revisit-requirements / cancel)"

### Phase 3 — Tasks
1. Invoke `tasks-agent` subagent with requirements.md + design.md + steering
2. Subagent breaks design into atomic tasks (each ≈ 1 PR worth of change)
3. Output: `.claude/specs/<feature-name>/tasks.md` with checkboxes
4. **GATE**: ask "Approve tasks? (yes / edit / revisit-design / cancel)"

### Phase 4 — Validation Gate
1. Invoke `spec-validator` subagent with all three files
2. Validator checks: every requirement has a design element; every design element has a task; no orphan tasks; tasks are atomic and ordered
3. Report findings to user
4. If validation passes: print next-step instructions ("Run `/spec-execute <feature-name>` to begin implementation")
5. If validation fails: report issues, do NOT mark spec as approved

## Output Format (final report to user)

```
✓ Spec created: payment-vpc-pci

  Requirements: 7 user stories, 12 acceptance criteria
  Design: Cloud Posse VPC module v5.x, multi-AZ, 3 NAT gateways
  Tasks: 8 atomic tasks (estimated 2 days)

  Files:
  - .claude/specs/payment-vpc-pci/requirements.md
  - .claude/specs/payment-vpc-pci/design.md
  - .claude/specs/payment-vpc-pci/tasks.md

  Next: /spec-execute payment-vpc-pci
```

## Recovery

If user cancels mid-workflow, leave partial files in place with `.draft` suffix. Resume by re-running `/spec-create` on the same feature name.

## Anti-Patterns (do NOT do these)

- Do NOT generate code during this workflow — only specs
- Do NOT skip phases even if user insists ("just generate the code") — explain that bypass requires `/spec-execute --no-spec` flag (and that's logged)
- Do NOT auto-approve any phase — every gate requires explicit user input
- Do NOT modify steering files — those are constitutional
