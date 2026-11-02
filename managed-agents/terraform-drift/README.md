# Terraform drift triage with Managed Agents (self-hosted worker)

A scheduled Claude Managed Agents deployment that runs a **read-only** `terraform plan` in every
environment every weekday, triages the drift and keeps one GitHub issue per environment.
Companion to section 5.9.6 / 5.9.7 of *The AI-Native DevOps Engineer*.

## Why it is built this way

- **Self-hosted sandbox.** AWS credentials cannot go through a vault `environment_variable`
  credential (the placeholder is swapped at egress, which breaks SigV4 signing, and that credential
  type is not supported on self-hosted sandboxes). The worker runs in your account and assumes a
  plan-only role for one hour.
- **The agent never reads the raw plan.** `terraform show -json` carries attribute values in clear
  text, sensitive ones included. `drift-scan.sh` returns only addresses, actions and changed attribute
  names. Every tool output goes to the session transcript.
- **Memory vs decisions.** The agent's memory store (`drift-ledger`) remembers what it already
  reported. Accepted drift lives in `drift/accepted.yaml`, merged by a human, with an expiry date.

## Layout

```
platform-agents/                 # applied with `ant apply` (plan on PR, apply on merge)
  agents/tf-drift.md             # Sonnet 5.5, GitHub MCP with 3 tools only, no web tools
  deployments/nightly-drift.md   # cron 30 5 * * 1-5 UTC, US$ 5 budget per run
  environments/drift-runner.yaml # type: self_hosted
  memory_stores/drift-ledger.yaml
  vaults/github-drift.yaml       # name only; the PAT goes in through the CLI
worker/                          # runs on a host inside your AWS account
  spawn.sh                       # `ant beta:worker poll --on-work spawn.sh`
  Dockerfile, terraformrc        # pinned terraform + ant, local provider mirror
  drift-scan.sh, summarize.jq    # value-free JSON report
  host-role-policy.json          # host can only assume terraform-plan-readonly
infra-repo/                      # files that go into your Terraform repository
  drift/accepted.yaml            # human-approved exceptions, each with `expires`
  envs/prod/providers.tf         # `plan_only` variable that drops the write assume_role
```

## Setup

1. Create the plan-only role (section 5.9.5) and let `drift-worker-host` assume it.
2. Build the image: pin `terraform` and `ant`, run
   `terraform providers mirror -platform=linux_amd64 ./tf-mirror`, and make sure
   `.terraform.lock.hcl` has the `linux_amd64` hashes (`terraform providers lock -platform=linux_amd64`).
3. On the host, export `ANTHROPIC_ENVIRONMENT_KEY` / `ANTHROPIC_ENVIRONMENT_ID` from your secrets
   manager and run `ant beta:worker poll --on-work /opt/drift/spawn.sh` as a service.
4. From your machine or CI: `ant apply --dry-run platform-agents/`, then `ant apply platform-agents/`.
5. Add a fine-grained GitHub PAT (Issues read/write, Metadata read) to the vault with
   `ant beta:vaults:credentials create` (`static_bearer`, `mcp_server_url: https://api.githubcopilot.com/mcp/`).
6. Rehearse: `ant beta:deployments run --deployment-id "$DEPLOYMENT_ID"` and check the issue contains
   fingerprints and no attribute values.

## What it never does

No `apply`, no `apply -refresh-only`, no edits to `accepted.yaml`. Remediation and acceptance are
human decisions made in a PR.

## Limits (beta)

- On Claude Platform on AWS, memory stores cannot be attached to self-hosted sessions: keep the
  fingerprint list in the issue body and drop the `resources` entry.
- Sessions keep transcripts until you delete them (not ZDR eligible).
- The plan-only role can read the state bucket; secrets in state are reachable from `bash`. Move them
  out of state with write-only arguments (Terraform 1.11+) and ephemeral values (1.10+).

Docs: https://platform.claude.com/docs/en/managed-agents/scheduled-deployments ·
https://platform.claude.com/docs/en/managed-agents/self-hosted-sandboxes
