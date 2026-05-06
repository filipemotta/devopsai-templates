---
name: spec-validate
description: Validate that an approved spec is internally consistent and that current code/infra matches it (drift detection)
context: fork
allowed-tools: Read(*) Glob(*) Grep(*) Bash(terraform plan:*, kubectl diff:*, promtool check:*, promtool query:*, git status:*, git log:*)
---

# /spec-validate

> **Frontmatter notes**:
> - `context: fork` — validator runs without prior conversation bias (clean evaluation)
> - `allowed-tools` — read-only file access plus narrow Bash allowlist for drift detection commands across Terraform, Kubernetes, Prometheus, and Git. No Write/Edit (validators never modify state).


Two modes:
1. **Internal consistency** — every requirement has a design element; every design has tasks; tasks are atomic
2. **Drift detection** — current code/infra state matches what the spec describes

## Usage

```
/spec-validate <feature-name>           # internal consistency
/spec-validate <feature-name> --drift   # drift detection
/spec-validate <feature-name> --all     # both
```

## Prerequisites

- Spec exists in `.claude/specs/<feature-name>/`
- Subagent `spec-validator` available
- For `--drift`: domain tooling installed (`terraform`, `kubectl`, `promtool`, etc.)

## Workflow — Internal Consistency

### Step 1 — Coverage matrix
For each requirement (R1, R2, ...) in `requirements.md`:
- Find at least one design element in `design.md` that addresses it
- Find at least one task in `tasks.md` that implements it
- Report orphan requirements

For each task in `tasks.md`:
- Find the design element it implements
- Report orphan tasks (work without justification)

### Step 2 — Atomicity check
Each task must:
- Reference specific file paths
- Be completable in one PR-sized change
- Have clear acceptance criteria

Flag tasks that are vague ("set up the thing", "configure stuff") or too large ("implement entire module").

### Step 3 — Steering compliance
Cross-check spec against `.claude/steering/*.md`:
- Tech choices match steering/tech.md (e.g., correct framework versions)
- Naming follows steering/structure.md
- Compliance constraints from steering/product.md are addressed

### Step 4 — Report
```
Spec: payment-vpc-pci

Coverage:
  Requirements: 7 / 7 covered
  Design elements: 12 / 12 have tasks
  Orphan tasks: 0

Atomicity:
  ✓ All 8 tasks reference specific paths
  ✓ All 8 tasks have acceptance criteria

Steering compliance:
  ✓ tech.md: AWS provider ~> 5.0 matches
  ✓ structure.md: naming follows <env>-<region>-<resource>
  ⚠ product.md: PCI requirement requires KMS CMK — not in design.md

Result: 1 warning, 0 errors. Address PCI/KMS in design before proceeding.
```

## Workflow — Drift Detection

### Step 1 — Load expected state
Parse `tasks.md` to extract files/resources that should exist post-implementation.

### Step 2 — Compare to actual

**Terraform**:
```bash
terraform plan -refresh-only -no-color > /tmp/drift.txt
```
Parse output. Any "drift" entries = divergence from last apply. Compare to design.md to determine: was this intentional and not specced, or unauthorized?

**Kubernetes**:
```bash
kubectl get -f manifests/ -o yaml > /tmp/actual.yaml
diff -u manifests/ /tmp/actual.yaml
```

**Observability (Prometheus)**:
```bash
promtool query instant http://prometheus:9090 '<sli-query-from-slo.md>'
```
Confirm SLI is being measured as defined. Confirm alerts are firing as designed.

### Step 3 — Reconciliation report
```
Drift detected:
  - aws_security_group.allow_ssh: port 22 added (not in spec)
  - aws_iam_role.payment: tag "Owner" missing

Suggested actions:
  1. Update spec (legitimate change): edit design.md, re-approve, add to tasks.md
  2. Revert state (unauthorized change): apply spec to bring back to compliance
  3. Accept drift: append exception to spec with rationale
```

## Integration with CI

`/spec-validate --all --format=json` returns machine-readable output for CI gates:

```yaml
# .github/workflows/spec-check.yml
- name: Validate specs
  run: |
    claude /spec-validate $(ls .claude/specs/) --all --format=json | tee report.json
    if jq -e '.errors > 0' report.json; then exit 1; fi
```

## Anti-Patterns

- Do NOT auto-fix drift — always report and let human decide reconciliation
- Do NOT modify spec files during validation — read-only
- Do NOT pass validation on warnings — only "0 errors and 0 warnings" should green-light
