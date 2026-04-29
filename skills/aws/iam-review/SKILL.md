---
description: "Review IAM permissions for least privilege compliance (AWS)"
allowed-tools: Read, Grep, Glob, Bash(aws iam:*), Bash(aws sts:*), Bash(aws organizations:*)
---

# /iam-review

## Data Collection
1. **List IAM Roles and Policies**:
   - `aws iam list-roles` - All roles in the account
   - `aws iam list-policies --scope Local` - Custom policies
   - For each role: `aws iam list-attached-role-policies`
   - For each role: `aws iam list-role-policies` (inline)

2. **Analyze Inline vs Managed Policies**:
   - Flag inline policies (harder to audit and reuse)
   - Check managed policy versions and drift

3. **Check Permissions Boundaries**:
   - `aws iam get-role` - PermissionsBoundary field
   - Flag roles WITHOUT permissions boundaries

4. **Cross-Account Access**:
   - Check trust policies for external account IDs
   - Verify `sts:ExternalId` condition exists
   - Flag overly broad trust (`Principal: "*"`)

5. **Service-Linked Roles**:
   - Identify auto-created service roles
   - Verify they match active services

## Analysis Checklist
- [ ] **Wildcard Actions**: Policies with `s3:*`, `ec2:*`, `iam:*`
- [ ] **Wildcard Resources**: Policies with `Resource: "*"`
- [ ] **Missing Conditions**: No IP restriction, no MFA requirement
- [ ] **Admin Access**: Roles with `AdministratorAccess` policy
- [ ] **Access Keys**: IAM users with access keys (prefer roles)
- [ ] **Unused Permissions**: Last accessed >90 days (via Access Advisor)
- [ ] **Cross-Account Trust**: Verify all trusted accounts are known
- [ ] **Assume Role Chains**: Role A assumes B assumes C (excessive)

## Output
1. **Risk Score**: X/10 (10 = most risky)
2. **Critical**: Admin access, wildcard permissions, public trust
3. **Warnings**: Unused permissions, missing conditions, inline policies
4. **Recommendations**: Specific least-privilege policy suggestions
5. **Policy Suggestions**: JSON of corrected IAM policies

For each finding, provide the **current** policy snippet and the **recommended** replacement.
