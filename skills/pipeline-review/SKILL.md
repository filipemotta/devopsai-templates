---
description: "Security and best practices review for CI/CD pipelines"
---

# /pipeline-review

## Data Collection
1. Find all workflow files (.github/workflows/*.yml, .gitlab-ci.yml, Jenkinsfile)
2. Read each workflow and catalog: triggers, jobs, steps, actions used
3. Check for CODEOWNERS file protecting workflow directory
4. If GitHub: `gh api repos/{owner}/{repo}/branches/{branch}/protection` for branch rules

## Security Checklist
- [ ] Secrets hardcoded in workflow files (API keys, tokens, passwords)
- [ ] Third-party actions without SHA pinning (supply chain risk)
- [ ] GITHUB_TOKEN permissions too broad (should use least privilege)
- [ ] No CODEOWNERS protecting .github/workflows/ directory
- [ ] Jobs running on self-hosted runners without isolation
- [ ] Workflow triggered by pull_request_target with code checkout (injection risk)
- [ ] Artifacts containing secrets or sensitive data
- [ ] Environment variables logged in debug output
- [ ] Missing branch protection rules on main/production branches
- [ ] Steps with `continue-on-error: true` on security checks

## Performance Checklist
- [ ] No cache strategy (slow dependency installs every run)
- [ ] No matrix strategy for multi-version testing
- [ ] Sequential jobs that could run in parallel
- [ ] Large Docker images without layer caching
- [ ] Artifacts without retention policy (storage costs)
- [ ] Full git clone when shallow clone would suffice
- [ ] No timeout-minutes set (zombie jobs)
- [ ] Redundant steps across jobs (no reusable workflows)

## Best Practices Checklist
- [ ] No concurrency group (duplicate runs on rapid pushes)
- [ ] Missing required status checks
- [ ] No dependency review for PRs
- [ ] Inconsistent naming conventions across workflows
- [ ] No workflow_dispatch for manual triggers
- [ ] Missing job-level if conditions for skip logic

## Output Format
Return structured report:
1. **Score**: Security X/10, Performance X/10, Best Practices X/10
2. **Critical**: Supply chain risks, secret exposure
3. **Warnings**: Missing permissions scoping, no caching
4. **Recommendations**: Optimization opportunities
5. **Quick Wins**: Changes that take <5 min with high impact
