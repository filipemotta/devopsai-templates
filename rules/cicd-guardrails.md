# CI/CD Guardrails

Drop this file into `.claude/rules/cicd-guardrails.md` in your
application/pipeline repository. Cite your ADRs so the agent's answers
trace back to recorded decisions.

- AI NEVER merges: auto-fix opens a PR, a human reviews and approves.
- Rollback is assisted: the AI correlates deploy × metrics, presents
  evidence and the command; the human confirms.
- The pipeline only writes to git and the registry; the GitOps
  operator writes to the cluster.
- New workflows use OIDC federation: never suggest static access keys
  in secrets.
- Production artifacts ship signed (Cosign) with an SBOM; deploying
  without signature verification is a BLOCKER.
