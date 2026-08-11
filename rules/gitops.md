# GitOps Rules

Drop this file into `.claude/rules/gitops.md` in your GitOps repository.
Rules should cite your ADRs (replace the ADR numbers with yours) so the
agent's answers always trace back to a recorded decision.

- The cluster is read-only for humans and agents: every change is born
  as a PR.
- Only the GitOps operator (ArgoCD/Flux) writes to the cluster; CI and
  agents only write to git (ADR-001).
- Images always by immutable tag `sha-<git-sha>`; never `:latest`
  (ADR-001).
- Promotion between environments = PR changing the target environment's
  overlay (ADR-002). Never edit `base/` to promote.
- Rollback = `git revert` + sync. Never `kubectl rollout undo`.
- Production PRs reference the applicable ADR in the description.
- Removing a resource from a kustomization with `prune` enabled: treat
  as BLOCKER until human confirmation (ADR-001).
