# CLAUDE.md - Terraform Agent Teams Template

Use this template to add Agent Teams configuration for Terraform infrastructure refactoring projects. Copy and merge into your project's `CLAUDE.md`.

> Requires: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json`

---

## Terraform Refactoring - Agent Team Configuration

### When to Use Agent Teams
Use Agent Teams (instead of a single agent) when:
- Refactoring affects **> 20 resources**
- Changes span **> 2 modules** or environments
- State moves are required
- Security + Cost + Dependencies need simultaneous review

### Agent Team Roles

**refactor-planner (lead):**
- Reads current codebase structure
- Creates modularization plan
- Delegates to specialist agents
- Consolidates final report with go/no-go decision

**security-reviewer:**
- Scans for CRITICAL/HIGH vulnerabilities
- Checks: SG rules, IAM, encryption, public exposure
- Must block refactoring if CRITICAL issues exist

**cost-analyzer:**
- Compares current vs optimal resource sizing
- Identifies Reserved Instance opportunities
- Reports monthly savings potential

**blast-radius-mapper:**
- Maps all cross-resource dependencies
- Generates `terraform state mv` commands in correct order
- Validates that final plan shows 0 changes
- Identifies outputs needed for cross-module references

### Task Dependencies
- Tasks 1, 2, 3 (analysis): Run in PARALLEL (no dependencies)
- Task 4 (Consolidation): blockedBy [1, 2, 3]
- Task 5 (Final Report + state mv script): blockedBy [4]

### Safety Rules (ALL agents)
- **NEVER** execute `terraform apply` or `terraform destroy`
- **NEVER** modify `.tfstate` files directly
- **ALWAYS** generate state mv as a script for human review
- **ALWAYS** recommend state backup before any move
- Use `terraform plan -detailed-exitcode` for verification
- Test in dev environment before staging/prod

### Report Format
Final report MUST include:
1. GO / CONDITIONAL GO / NO-GO decision
2. Modularization plan with new directory structure
3. Complete `terraform state mv` script (ordered by dependencies)
4. Security findings (CRITICAL/HIGH/MEDIUM)
5. Cost optimization opportunities with monthly savings estimate
6. Blast radius map showing cross-resource dependencies
7. Verification steps to confirm 0-change plan after moves

### Example Prompt
```
I need to refactor our monolithic main.tf (~2000 lines) into proper modules.

Create an agent team:
1. refactor-planner (LEAD): Analyze the current structure and create a modularization plan
2. security-reviewer: Audit all resources for security issues (SG, IAM, encryption)
3. cost-analyzer: Identify cost optimization opportunities
4. blast-radius-mapper: Map dependencies and generate state mv commands

Rules:
- NEVER run terraform apply or destroy
- Generate all state mv commands as a reviewable script
- Final report must include go/no-go decision
- Each agent messages others when finding cross-cutting concerns
```

### Best Practices
1. **Always backup state first**: `terraform state pull > terraform.tfstate.backup`
2. **Validate after each move batch**: Run `terraform plan` to check for 0 changes
3. **Group moves by module**: Move all resources for one module before starting the next
4. **Keep outputs stable**: When splitting modules, ensure outputs are preserved for consumers
5. **Test in lower environments**: Never refactor production state without testing the same moves in dev/staging first
