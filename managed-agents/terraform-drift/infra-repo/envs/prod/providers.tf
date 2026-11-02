# envs/prod/providers.tf
variable "plan_only" {
  type        = bool
  default     = false
  description = "true in the scheduled drift run: use the ambient credentials, already in the plan-only role"
}

provider "aws" {
  region = "us-east-1"

  # Normal flow (human or CI): assume the environment role, as in section 5.9.5.
  # Scheduled drift: TF_VAR_plan_only=true drops assume_role and the provider uses
  # the temporary credentials exported by spawn.sh.
  dynamic "assume_role" {
    for_each = var.plan_only ? [] : [1]
    content {
      role_arn = "arn:aws:iam::111122223333:role/terraform-apply"
    }
  }
}
