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
├── CLAUDE-terraform-agent-teams.md # Agent Teams for Terraform refactoring
├── CLAUDE-incident-response-agent-teams.md # Agent Teams for incident war rooms
├── claude-settings.json           # .claude/settings.json (with hooks)
├── hooks/                         # Claude Code hooks
│   └── hooks-devops.json          # All DevOps hooks (PreToolUse, PostToolUse, Stop, etc.)
├── skills/                        # Claude Code skills by domain
│   ├── aws/                       # AWS-specific skills
│   │   ├── eks-upgrade/           # EKS upgrade verification (deprecated APIs, addons)
│   │   ├── karpenter-debug/       # Karpenter troubleshooting (NodeClaim, consolidation)
│   │   ├── karpenter-provision/   # Generate NodePool + EC2NodeClass configs
│   │   └── iam-review/            # AWS IAM least-privilege review
│   ├── gcp/                       # GCP-specific skills
│   │   ├── gke-multi-region-bootstrap/  # Agent-team provisioning across regions
│   │   └── gke-incident-triage/   # Read-only-first GKE incident response
│   ├── terraform/                 # Cloud-agnostic Terraform skills
│   ├── terraform-plan/
│   ├── terraform-review/
│   ├── kubernetes/                # Cloud-agnostic K8s skills
│   ├── k8s-debug/
│   ├── k8s-review/
│   ├── cicd/                      # CI/CD generic
│   ├── pipeline-debug/
│   ├── pipeline-review/
│   ├── observability/
│   ├── incident-debug/
│   ├── security/
│   ├── security-scan/
│   ├── finops/
│   ├── cost-review/
│   ├── gitops/
│   └── devops-general/
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
- `CLAUDE-eks-upgrade.md` - EKS upgrade project with Agent Teams validation
- `CLAUDE-terraform-agent-teams.md` - Agent Teams for Terraform refactoring
- `CLAUDE-incident-response-agent-teams.md` - Agent Teams for incident war rooms

**Usage:**
```bash
cp templates/CLAUDE-complete.md CLAUDE.md
# Edit with your project information
```

### 3. `.claude/settings.json`

Claude Code permissions, settings, and hooks. Includes PreToolUse safety checks, PostToolUse auto-validation (Terraform fmt, YAML lint), and Stop verification hooks.

**Usage:**
```bash
mkdir -p .claude
cp templates/claude-settings.json .claude/settings.json
```

### 4. `hooks-devops.json`

Standalone hooks configuration with all DevOps-specific hooks. Use this if you want to add hooks to an existing settings.json, or as a reference for building your own.

Includes:
- **SessionStart** - Auto-detect project type (Terraform, Docker, K8s)
- **PreToolUse** - Block destructive commands (terraform destroy, kubectl delete namespace, rm -rf, git push --force)
- **PostToolUse** - Auto-validate edited files (.tf, .yaml, Dockerfile) + audit logging
- **Stop** - Verify task completion before agent stops
- **SubagentStop** - Verify subagent task completion

**Usage:**
```bash
# Copy the hooks section into your existing .claude/settings.json
# Or use as standalone reference
cat templates/hooks/hooks-devops.json
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

## Agent Teams Templates (Opus 4.6)

Agent Teams is an experimental Claude Code feature that enables multiple coordinated AI agents working in parallel with shared task lists. These templates configure Agent Teams for specific DevOps scenarios.

> Requires: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json`

### CLAUDE-eks-upgrade.md
Complete EKS upgrade template with Agent Teams multi-agent validation.
- 4 agents: upgrade-coordinator, compatibility-checker, workload-validator, security-auditor
- Parallel validation of addons, APIs, workloads, and security
- GO / CONDITIONAL GO / NO-GO decision framework

### CLAUDE-terraform-agent-teams.md
Agent Teams configuration for Terraform infrastructure refactoring.
- 4 agents: refactor-planner, security-reviewer, cost-analyzer, blast-radius-mapper
- Parallel analysis of security, cost, and dependencies
- Safe state move script generation

### CLAUDE-incident-response-agent-teams.md
Agent Teams configuration for automated incident war rooms.
- 4 agents: incident-commander, logs-investigator, metrics-analyzer, deploy-auditor
- Parallel investigation across logs, metrics, and deployments
- RCA consolidation with confidence levels

**Usage:**
```bash
# Merge the relevant Agent Teams section into your CLAUDE.md
cat /path/to/templates/CLAUDE-terraform-agent-teams.md >> CLAUDE.md

# Enable Agent Teams in settings
echo '{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }' > .claude/settings.json
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
