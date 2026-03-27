---
description: "Automatic diagnosis of CI/CD pipeline failures"
---

# /pipeline-debug

## Data Collection
1. Read the workflow file (.github/workflows/, .gitlab-ci.yml, Jenkinsfile)
2. If GitHub Actions: `gh run list --limit 5` for recent executions
3. If available: `gh run view <id> --log-failed` for failure logs
4. Check recent commits that may have caused the failure

## Analysis Checklist
- [ ] Failed step: which command, exit code, stderr output
- [ ] Dependencies: did Node/Python/Go versions change?
- [ ] Secrets: missing or expired environment variables?
- [ ] Cache: invalidated cache causing full rebuild?
- [ ] Timing: did job exceed timeout limit?
- [ ] Flaky tests: does the same step fail intermittently?
- [ ] Docker: base image changed, layer caching broken?
- [ ] Permissions: GITHUB_TOKEN missing required scopes?
- [ ] Network: external service/registry unreachable?
- [ ] Concurrency: parallel jobs competing for resources?

## Output Format
Return structured diagnosis:
1. **Root Cause**: What caused the failure (with evidence from logs)
2. **Fix**: Exact command or workflow change to resolve
3. **Prevention**: How to avoid in the future (pinning, retry, cache key)
4. **Confidence**: HIGH/MEDIUM/LOW based on evidence available
