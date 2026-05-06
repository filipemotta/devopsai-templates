---
name: spec-execute
description: Implement the next unchecked task from an approved tasks.md, one task at a time, with validation
context: fork
allowed-tools: Read(*) Write(*) Edit(*) Glob(*) Grep(*) Bash(*)
---

# /spec-execute

> **Frontmatter notes**:
> - `context: fork` — implementation runs in isolated context; conversation history doesn't leak in
> - `allowed-tools` — broad permissions because implementation needs to write code; the `enforce-spec` PreToolUse hook is the actual scope guard (blocks Write/Edit outside approved task paths)


Execute one task from an approved spec's `tasks.md`. Designed to keep agent focus narrow — one PR-sized change per invocation.

## Usage

```
/spec-execute <feature-name> [--task <task-id>]
```

If `--task` not provided, picks the first unchecked task in order.

## Prerequisites

- `.claude/specs/<feature-name>/tasks.md` exists and was approved by `/spec-create`
- Subagent `implementation-agent` available
- Hook `enforce-spec` is registered (will allow Edit/Write only on files listed in current task)

## Workflow

### Phase 1 — Load context
1. Read `.claude/specs/<feature-name>/requirements.md`
2. Read `.claude/specs/<feature-name>/design.md`
3. Read `.claude/specs/<feature-name>/tasks.md`
4. Identify target task (first `- [ ]` or specified by `--task`)
5. Read all `.claude/steering/*.md`

### Phase 2 — Pre-flight check
1. Validate target task references specific file paths
2. Set environment: export `CLAUDE_SPEC_ACTIVE=<feature-name>` and `CLAUDE_SPEC_TASK=<task-id>` (so `enforce-spec` hook knows what's allowed)
3. Confirm with user: "About to implement: <task description>. Files affected: <list>. Proceed?"

### Phase 3 — Implementation
1. Invoke `implementation-agent` subagent with:
   - Target task description
   - Allowed file paths (from task)
   - Full requirements + design + steering context
2. Subagent writes ONLY the files in scope. Hook blocks any other Edit/Write.
3. After files written, run domain-specific validation:
   - **Terraform**: `terraform fmt && terraform validate && terraform plan -no-color`
   - **K8s**: `kubeval *.yaml && kube-score score *.yaml`
   - **Observability**: `promtool check rules *.yaml`
   - **Generic code**: lint + type-check (project-defined in steering/tech.md)

### Phase 4 — Verification
1. Invoke `spec-validator` subagent to confirm output matches the task's acceptance criteria
2. If pass: mark task as `[x]` in `tasks.md`, append timestamp comment
3. If fail: roll back, report errors to user, do NOT mark complete

### Phase 5 — Report
```
✓ Task completed: 3.2 — Generate vpc/main.tf with Cloud Posse module

  Files changed:
  - terraform/environments/prod/vpc/main.tf (+45 lines)
  - terraform/environments/prod/vpc/variables.tf (+22 lines)

  Validation:
  ✓ terraform fmt
  ✓ terraform validate
  ✓ terraform plan: 8 resources to add

  Remaining tasks: 5 of 8
  Next: /spec-execute payment-vpc-pci
```

## Multi-task mode

If user asks for "implement all tasks" or `--all` flag:
1. Refuse by default — defeats the per-task review safety
2. If forced: invoke `/spec-execute` in loop, BUT pause for user approval between tasks
3. Never run >1 task without an explicit "continue" from user

## Bypass mode (emergencies only)

For incident response or hotfix when SDD is overhead:

```
/spec-execute --no-spec "fix typo in payment-service config"
```

This bypasses the workflow but:
- Logs the bypass to `.claude/spec-bypass.log` (for audit)
- Disables enforce-spec hook for this invocation only
- Requires natural-language description of what's being changed

Use sparingly. Bypasses should be < 10% of changes.

## Anti-Patterns

- Do NOT generate files outside the task's listed paths (the hook will block, but agent should not even try)
- Do NOT modify the spec files (`requirements.md`, `design.md`, `tasks.md`) during execution — those are immutable per release
- Do NOT mark task as complete if validation fails — leave it open
- Do NOT skip the pre-flight gate — user must approve scope before agent writes code
