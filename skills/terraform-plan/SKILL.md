---
description: "Analyze terraform plan output — blast radius, risks, cost impact"
---

# /terraform-plan

## Execution
1. Run `terraform plan -out=tfplan` (or ask user to paste plan output)
2. If tfplan file exists: `terraform show -json tfplan`
3. Parse the plan JSON or text output

## Analysis
For each resource change:
- **Create**: What's being created? Estimated cost?
- **Update**: What fields changed? Is it in-place or replace?
- **Delete**: Why? Was it renamed (should use state mv)?
- **Replace (destroy+create)**: DANGER — will cause downtime? (e.g., RDS, EBS)

## Blast Radius Assessment
- Count total resources affected
- Identify dependencies (what else might break?)
- Flag resources that cause downtime on replace (databases, load balancers, DNS)
- Check if any resource is being destroyed that has dependents

## Risk Classification
- SAFE: Create-only, or update in-place on non-critical resources
- CAUTION: Updates that might cause brief disruption
- DANGER: Deletes, replaces on stateful resources, or changes affecting production traffic

## Output Format
Return:
1. **Summary**: X creates, Y updates, Z deletes
2. **Blast Radius**: Low/Medium/High with explanation
3. **Risk Items**: Each flagged item with classification
4. **Cost Delta**: Estimated cost change (if infracost available)
5. **Recommendation**: Safe to apply / Needs review / DO NOT APPLY without manual verification
