---
description: "Run a comprehensive security scan on the project (secrets, CVEs, Docker, IaC, RBAC)"
allowed-tools: Read, Grep, Glob, Bash(npm audit:*), Bash(pip audit:*), Bash(trivy:*), Bash(kubectl:*), Bash(git log:*)
---

# /security-scan

## Data Collection
1. **Secrets Detection**: Scan source code for hardcoded credentials
   - Patterns: AWS access keys (`AKIA[0-9A-Z]{16}`), tokens, passwords in config files
   - Check: `.env` files committed to git, private keys in repo
   - Tool: `Grep` with regex patterns + `git log` for history

2. **Dependency Vulnerabilities**: Check known CVEs
   - Node.js: `npm audit --json` or `yarn audit --json`
   - Python: `pip audit --format=json`
   - Go: `govulncheck ./...`
   - General: `trivy fs --format json .` (if available)

3. **Dockerfile Analysis**: Check container security
   - Running as root (no USER directive)
   - Using `:latest` tag instead of pinned versions
   - Secrets passed via ARG/ENV or COPY
   - Missing multi-stage build (large attack surface)

4. **IaC Misconfigurations**: Terraform / CloudFormation
   - S3 buckets with public access
   - Security Groups with `0.0.0.0/0` ingress
   - Unencrypted storage (EBS, RDS, S3)
   - Missing logging/audit trail

5. **Kubernetes RBAC**: If K8s manifests present
   - ClusterRoleBindings with `cluster-admin`
   - Wildcard permissions in Roles
   - ServiceAccounts with excessive permissions

## Security Checklist
- [ ] **Secrets**: No hardcoded credentials in source code
- [ ] **Dependencies**: No known critical/high CVEs
- [ ] **Docker**: Images don't run as root, multi-stage build used
- [ ] **IaC**: S3 not public, SGs without 0.0.0.0/0, encryption enabled
- [ ] **RBAC**: No unnecessary cluster-admin bindings
- [ ] **TLS**: Endpoints use HTTPS, certificates valid
- [ ] **Logging**: Audit trail enabled
- [ ] **Secrets Mgmt**: Using vault/external-secrets, not plain env vars

## Output
1. **Risk Level**: Critical / High / Medium / Low
2. **Findings**: Categorized list by severity
   - For each: file, line, description, remediation command
3. **OWASP Top 10**: Which risks apply to this project
4. **Remediation**: Specific command or change for each finding
5. **Compliance**: Status vs frameworks (SOC2, HIPAA, PCI-DSS basics)
