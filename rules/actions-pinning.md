# Actions and Workflows

Drop this file into `.claude/rules/actions-pinning.md`.

- Production workflows pin actions by full SHA; Renovate/Dependabot
  handles the version bumps.
- `.github/workflows/` is protected by CODEOWNERS; workflow changes
  require platform-team review.
- `pull_request_target` only with an explicit security review (it is
  the classic secret-exfiltration vector).
- `GITHUB_TOKEN` with minimum permissions declared per job; never
  inherit write-all.
- Generated a new workflow? Run your pipeline-review skill (or the
  pipeline-reviewer subagent) before the first commit.
