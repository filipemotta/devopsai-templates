---
name: terraform-deploy
description: >
  Runs the Terraform stack deploy pipeline (fmt → validate → plan → apply) in
  sandbox/dev environments. Use when the user asks to deploy, apply, provision
  or bring up Terraform infrastructure in a non-production environment, even
  without mentioning "terraform-deploy" explicitly. With a stack name as
  argument (e.g. "01-networking"), deploys only that stack; with no argument,
  deploys all stacks in sequence. Always skips the remote-backend stack.
  NEVER use against a production workspace/environment.
---

## What this skill does

Runs the complete deploy pipeline for one or more Terraform stacks:

1. `terraform fmt` — formats the code
2. `terraform validate` — validates the configuration
3. `terraform plan` — generates and shows the execution plan
4. `terraform apply -auto-approve` — applies the changes

## Safety boundary (read first)

This is an EXECUTION skill for **sandbox and dev only**:

- Before step 4, confirm the target is not production. Check, in this order:
  `terraform workspace show` is not `production`; the `-var-file` in use is
  not a production file; the AWS account is not the production account.
  If any check points to production, STOP and tell the user that production
  applies belong in CI with human approval.
- Pair this skill with hard guardrails (plan-only IAM role for production,
  permission boundaries, SCPs). A skill is a soft guardrail, not a substitute.

## Identifying stacks

Stacks are directories containing `*.tf` files, typically prefixed with a
two-digit order number (`00-`, `01-`, `02-`...). Rules:

- ALWAYS skip remote-backend stacks (any variation: `00-remote-backend`,
  `remote_backend`, `remote-backend-stack`). Their state bootstraps the
  others and never enters bulk operations.
- List candidates with: `ls -d */` from the Terraform root.

## Arguments

- **With argument** (e.g. `/terraform-deploy 01-networking`): deploy only the
  specified stack.
- **No argument**: discover all stacks (except remote-backend) and deploy each
  one sequentially, in numeric order. Never in parallel (state and dependency
  conflicts).

## Deploy pipeline per stack

Run the steps below for each stack, always in order. If any step fails, stop
and report the error before continuing.

### Step 1 — fmt
```bash
cd <stack-path>
terraform fmt
```
If files were reformatted, list them. Not an error, just record it.

### Step 2 — validate
```bash
terraform validate
```
If it fails, show the complete error message and do NOT proceed to the next
steps for this stack.

### Step 3 — plan
```bash
terraform plan -var-file="envs/dev.tfvars"
```
Show the complete plan output to the user before continuing. If there is no
`envs/dev.tfvars`, run without `-var-file` and record that in the report.

### Step 4 — apply
```bash
terraform apply -auto-approve -var-file="envs/dev.tfvars"
```
Only after the safety boundary checks passed. If there is no
`envs/dev.tfvars`, run without `-var-file`.

## Expected output

For each stack, present a clear status block:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stack: 01-networking
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ fmt      — OK
✓ validate — Success
✓ plan     — 12 to add, 0 to change, 0 to destroy
✓ apply    — Apply complete! Resources: 12 added
```

If any step fails, mark it with `✗` and show the error message. When deploying
multiple stacks, show a final summary for all of them.
