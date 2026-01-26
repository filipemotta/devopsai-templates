# Templates for Claude Code + Cursor

This directory contains ready-to-use templates to configure your AI environment for DevOps.

## Structure

```
templates/
├── README.md                      # This file
├── cursorrules-devops.txt         # Basic .cursorrules
├── cursorrules-agent.txt          # Advanced .cursorrules for agents
├── CLAUDE-devops.md               # Basic CLAUDE.md
├── CLAUDE-complete.md             # Complete CLAUDE.md (all details)
├── claude-settings.json           # .claude/settings.json
└── subagents/                     # Specialized subagents
    ├── k8s-troubleshoot.md        # Kubernetes troubleshooting
    ├── terraform-reviewer.md      # Terraform security & cost review
    ├── ci-security-analyst.md     # CI/CD vulnerability analysis
    ├── incident-analyzer.md       # Production incident investigation
    └── security-auditor.md        # Security audit & CVE triage
```

## Configuration Files

### 1. `.cursorrules`

Defines the AI agent's behavior.

**Options:**
- `cursorrules-devops.txt` - Basic DevOps configuration
- `cursorrules-agent.txt` - Advanced configuration for agents

**Usage:**
```bash
cp templates/cursorrules-devops.txt .cursorrules
```

### 2. `CLAUDE.md`

Project context for Claude.

**Options:**
- `CLAUDE-devops.md` - Basic template to get started
- `CLAUDE-complete.md` - Complete template with all details

**Usage:**
```bash
cp templates/CLAUDE-complete.md CLAUDE.md
# Edit with your project information
```

### 3. `.claude/settings.json`

Claude Code permissions and settings.

**Usage:**
```bash
mkdir -p .claude
cp templates/claude-settings.json .claude/settings.json
```

## Specialized Subagents

Subagents go in `.claude/agents/` and are specialists in specific domains.

### k8s-troubleshoot.md
Kubernetes troubleshooting specialist.
- Pod, deployment, service diagnostics
- Log and event analysis
- Fix suggestions

**Usage:**
```bash
mkdir -p .claude/agents
cp templates/subagents/k8s-troubleshoot.md .claude/agents/
```

**Invoke:** `@k8s-troubleshoot the payment-service deployment has an error`

### terraform-reviewer.md
Terraform code reviewer focused on security and costs.
- Security Groups, IAM, encryption
- Cost optimization
- Best practices

**Usage:**
```bash
cp templates/subagents/terraform-reviewer.md .claude/agents/
```

**Invoke:** `@terraform-reviewer analyze all .tf files`

### ci-security-analyst.md
CI/CD pipeline security analyst.
- CVE triage
- Reachability analysis
- Supply chain security

**Usage:**
```bash
cp templates/subagents/ci-security-analyst.md .claude/agents/
```

**Invoke:** `@ci-security-analyst the workflow failed on Trivy scan`

### incident-analyzer.md
Production incident investigator.
- Temporal event correlation
- Pattern recognition
- Action recommendations

**Usage:**
```bash
cp templates/subagents/incident-analyzer.md .claude/agents/
```

**Invoke:** `@incident-analyzer the payment-api service has high latency`

### security-auditor.md
Security and compliance auditor.
- CVE triage with risk scoring
- Security configuration review
- Kubernetes security audit

**Usage:**
```bash
cp templates/subagents/security-auditor.md .claude/agents/
```

**Invoke:** `@security-auditor audit the production namespace security`

## Complete Quick Setup

Run in your project directory:

```bash
# Create directory structure
mkdir -p .claude/agents

# Copy main configurations
cp /path/to/templates/cursorrules-agent.txt .cursorrules
cp /path/to/templates/CLAUDE-complete.md CLAUDE.md
cp /path/to/templates/claude-settings.json .claude/settings.json

# Copy all subagents
cp /path/to/templates/subagents/*.md .claude/agents/
```

## Customization

After copying, edit the files to reflect:

1. **CLAUDE.md:**
   - Project name and architecture
   - Specific versions (K8s, Terraform, etc.)
   - Team standards and conventions
   - Contacts and escalation

2. **.cursorrules:**
   - Environment-specific rules
   - Additional security restrictions

3. **settings.json:**
   - Allowed/denied commands
   - Enabled MCPs

4. **Subagents:**
   - Adapt available tools
   - Adjust personas for your context

## Tips

1. **Review permissions** in `.claude/settings.json` - adjust for your trust level
2. **Keep CLAUDE.md updated** - it's the project "memory" for the AI
3. **Version these files** - commit to git for the whole team to use
4. **Start with one subagent** - add more as needed
5. **Test in dev environment** - before using in production
