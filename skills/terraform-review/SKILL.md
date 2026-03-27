---
description: "Terraform security, cost and best practices review"
---

# /terraform-review

## Data Collection
1. Find all .tf files in the project
2. Read each file and catalog: resources, data sources, variables, outputs
3. If terraform MCP available: run `terraform validate`
4. Check for .terraform.lock.hcl (provider versions locked?)

## Security Checklist
- [ ] S3 buckets: public access blocked? encryption enabled? versioning?
- [ ] Security Groups: no 0.0.0.0/0 on ingress (except ALB port 443)?
- [ ] IAM: no inline policies? no wildcard (*) actions?
- [ ] RDS/databases: not publicly accessible? encryption at rest?
- [ ] Secrets: no hardcoded credentials in .tf files?
- [ ] KMS: customer-managed keys for sensitive data?
- [ ] VPC: private subnets for databases/internal services?
- [ ] Logging: CloudTrail, VPC Flow Logs, S3 access logs enabled?

## Cost Optimization
- [ ] Instance types: right-sized for workload? (check for over-provisioned)
- [ ] Storage: gp3 instead of gp2? Lifecycle policies on S3?
- [ ] NAT Gateway: needed or can use VPC endpoints?
- [ ] Reserved capacity: long-running resources could use Reserved Instances/Savings Plans?
- [ ] Idle resources: security groups, EIPs, unused EBS volumes?

## Best Practices
- [ ] Provider version pinned with ~> constraint
- [ ] Backend configured (S3 + DynamoDB for state locking)
- [ ] Variables have descriptions and types
- [ ] Sensitive variables marked as sensitive = true
- [ ] Tags applied consistently (at least: Environment, Team, ManagedBy)
- [ ] Modules used for repeated patterns
- [ ] No count when for_each is more appropriate

## Output Format
Return structured report:
1. **Score**: Security X/10, Cost X/10, Best Practices X/10
2. **Critical Issues**: Must fix before apply
3. **Warnings**: Should fix soon
4. **Recommendations**: Nice to have improvements
5. **Estimated Monthly Cost**: If infracost available
