variable "region" {
  description = "AWS region for the POC"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "karpenter-upgrade-poc"
}

# The POC starts at N-1 on purpose: the whole point is to perform
# the upgrade to var.target_version by hand, following the runbook.
variable "cluster_version" {
  description = "Initial Kubernetes version (N-1). The upgrade to N is the exercise."
  type        = string
  default     = "1.32"
}

variable "target_version" {
  description = "Target Kubernetes version (N). Used only for tagging and docs."
  type        = string
  default     = "1.33"
}

# Check the Karpenter compatibility matrix BEFORE changing cluster versions:
# https://karpenter.sh/docs/upgrading/compatibility/
# If the pinned version below does not support target_version, upgrading the
# controller comes BEFORE the control plane hop (article, step two).
variable "karpenter_version" {
  description = "Karpenter chart/controller version. Validate against the compatibility matrix."
  type        = string
  default     = "1.8.1"
}

variable "vpc_cidr" {
  description = "CIDR for the POC VPC"
  type        = string
  default     = "10.42.0.0/16"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "eks-karpenter-upgrade-poc"
    ManagedBy = "terraform"
    TearDown  = "true"
  }
}
