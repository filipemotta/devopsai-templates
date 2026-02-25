---
description: Review code for security vulnerabilities (OWASP Top 10, secrets, misconfigurations)
allowed-tools: Read, Grep, Glob, Bash(trivy:*), Bash(semgrep:*), Bash(git diff:*), Bash(gitleaks:*)
argument-hint: [directory, file, or --staged]
---

# Security Review Command

Perform a comprehensive security review of $ARGUMENTS.

If `--staged` is passed, only review git staged files via `git diff --cached`.
If a directory or file is specified, scan that path recursively.
If no arguments, scan the current working directory.

## Scan Checklist

### 1. Secrets Detection (CRITICAL)
- API keys, passwords, tokens, private keys hardcoded in source
- AWS access keys, GCP service account keys, Azure credentials
- Database connection strings with embedded passwords
- JWT secrets, OAuth client secrets
- `.env` files committed to version control

### 2. Injection Risks (CRITICAL/HIGH)
- SQL injection (unsanitized user input in queries)
- Command injection (shell commands with user input)
- SSRF (user-controlled URLs in server requests)
- XSS (unescaped output in HTML/templates)
- Path traversal (user input in file paths)

### 3. Authentication & Authorization (HIGH)
- Missing authentication on endpoints
- Broken authorization / privilege escalation paths
- Insecure session management
- Weak password policies
- Missing CSRF protection

### 4. Infrastructure Security (HIGH)
- Open security groups (`0.0.0.0/0` ingress)
- IAM policies without least privilege (`*` actions/resources)
- Unencrypted storage (S3, EBS, RDS without encryption)
- Public S3 buckets or databases
- Missing VPC / network segmentation

### 5. Dependency Vulnerabilities (MEDIUM/HIGH)
- Known CVEs in packages (run `trivy fs .` if available)
- Outdated dependencies with security patches available
- Unpinned dependency versions

### 6. Container & Kubernetes (MEDIUM/HIGH)
- Containers running as root
- Missing `securityContext` (allowPrivilegeEscalation, readOnlyRootFilesystem)
- No resource limits (memory/CPU)
- Using `latest` tag instead of pinned versions
- Missing NetworkPolicies

### 7. Cryptography (MEDIUM)
- Weak algorithms (MD5, SHA1 for security purposes)
- Hardcoded initialization vectors or salts
- TLS < 1.2
- Insecure random number generation

## Output Format

For each finding, provide:

```
[SEVERITY] File:Line — Description
  Category: OWASP-XX
  Impact: What could happen if exploited
  Fix: Specific remediation with code example
```

### Severity Levels
- **CRITICAL**: Exploitable now, data breach risk (secrets, SQLi, RCE)
- **HIGH**: Significant risk, should fix before merge (auth bypass, open infra)
- **MEDIUM**: Should fix soon (weak crypto, missing headers)
- **LOW**: Best practice improvement (informational)

## Summary

After all findings, provide:
1. **Total findings** by severity
2. **Top 3 priorities** to fix first
3. **Overall risk assessment** (CRITICAL / HIGH / MEDIUM / LOW)
4. **Quick wins** — issues fixable in < 5 minutes
