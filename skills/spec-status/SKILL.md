---
name: spec-status
description: Show progress of in-flight specs — phase, completed tasks, remaining work, last activity
allowed-tools: Read(*) Glob(*) Bash(git log:*, git diff:*)
---

# /spec-status

> **Frontmatter notes**:
> - No `context: fork` — read-only inspection benefits from main conversation context
> - `allowed-tools` — read-only access. Bash limited to `git log` and `git diff` for activity tracking. No Write/Edit.


Show the current state of all specs in `.claude/specs/` or a specific feature.

## Usage

```
/spec-status [feature-name]
```

## Workflow

### Without argument — list all specs
1. List all directories under `.claude/specs/`
2. For each, determine phase:
   - No `requirements.md` → "draft"
   - Only `requirements.md` → "requirements"
   - + `design.md` → "design"
   - + `tasks.md` → "tasks"
   - tasks.md has `[x]` → "implementing (X/Y tasks)"
   - all `[x]` → "complete"
3. Print table

```
SPEC                  PHASE              PROGRESS    LAST ACTIVITY
payment-vpc-pci       implementing       3/8         2 hours ago
notification-svc      design             —           1 day ago
audit-log-pipeline    complete           7/7         5 days ago
```

### With argument — detail for one feature
1. Read all spec files for `<feature-name>`
2. Print:
   - Title (from requirements.md heading)
   - Current phase
   - Requirements summary (count of user stories)
   - Design summary (key decisions)
   - Tasks: list with checkbox state
   - Completed tasks: timestamps from tasks.md comments
   - Files modified: derived from git log (`git log --oneline -- $(grep -oP 'path/to/\S+' tasks.md)`)

```
Spec: payment-vpc-pci
Phase: implementing (3 of 8 tasks complete)

Requirements:
  7 user stories, 12 acceptance criteria
  Compliance: PCI-DSS

Design:
  Module: terraform-aws-modules/vpc/aws ~> 5.5
  Multi-AZ: yes (3 AZs)
  NAT strategy: 1 per AZ (HA)

Tasks:
  [x] 1.1 — Create vpc/main.tf                        (2026-05-04 14:23)
  [x] 1.2 — Create vpc/variables.tf                   (2026-05-04 15:01)
  [x] 1.3 — Create vpc/outputs.tf                     (2026-05-05 09:15)
  [ ] 2.1 — Add VPC peering module
  [ ] 2.2 — Update backend.tf with state config
  [ ] 3.1 — Generate Kyverno baseline policies
  [ ] 4.1 — Run terraform validate + plan
  [ ] 4.2 — Document peering decisions in design.md

Next: /spec-execute payment-vpc-pci
```

## Drift check (optional flag)

```
/spec-status <feature> --drift
```

For completed specs, validate that current code state still matches spec:
- Run domain-specific drift detection (Terraform: `plan -refresh-only`, K8s: `kubectl diff`)
- Report any divergence: "Drift detected on `aws_security_group.allow_ssh` — port 22 added, not in spec. Reconcile?"

## Output as JSON (for CI)

```
/spec-status --format=json
```

Returns machine-parseable output for dashboards/CI:

```json
{
  "specs": [
    {
      "name": "payment-vpc-pci",
      "phase": "implementing",
      "tasks_total": 8,
      "tasks_complete": 3,
      "last_activity": "2026-05-05T09:15:00Z"
    }
  ]
}
```

## Anti-Patterns

- Do NOT modify any files — read-only command
- Do NOT prompt the user — pure information output
- Do NOT call other agents — direct file reads only
