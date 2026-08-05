# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true # POC: one NAT to keep cost down

  # Karpenter discovers subnets and security groups by this tag
  # (matches subnetSelectorTerms / securityGroupSelectorTerms in the EC2NodeClass)
  private_subnet_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# EKS cluster at N-1
#
# The small managed node group below exists ONLY to host the Karpenter
# controller and critical system components. This avoids the circular
# bootstrap dependency described in the article: the controller cannot
# depend exclusively on Karpenter-provisioned capacity, because a Pending
# controller pod has nobody to create the capacity it needs to start.
# -----------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  # Addons pinned explicitly. Before the control plane hop, move these to
  # versions compatible with BOTH cluster_version and target_version
  # (scripts/02-pre-upgrades.sh resolves the right versions).
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({ replicaCount = 2 })
    }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  eks_managed_node_groups = {
    karpenter-bootstrap = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      labels = {
        "karpenter.sh/controller" = "true"
      }
      # Keep general workloads off the bootstrap island so the POC's
      # rotation exercises happen on Karpenter-managed capacity only.
      taints = {
        controller = {
          key    = "karpenter.sh/controller"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Karpenter controller infrastructure (IAM role, instance profile, SQS for
# interruption handling) via the official submodule, then the Helm release.
# -----------------------------------------------------------------------------
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.31"

  cluster_name          = module.eks.cluster_name
  enable_v1_permissions = true

  enable_pod_identity             = true
  create_pod_identity_association = true

  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "KarpenterNodeRole-${var.cluster_name}"

  tags = var.tags
}

resource "helm_release" "karpenter" {
  namespace        = "kube-system"
  create_namespace = false

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version
  wait       = true

  values = [
    yamlencode({
      settings = {
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = module.karpenter.queue_name
      }
      # Pin the controller to the bootstrap island (see comment above).
      nodeSelector = {
        "karpenter.sh/controller" = "true"
      }
      tolerations = [
        {
          key      = "karpenter.sh/controller"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }
      ]
    })
  ]

  depends_on = [module.eks]
}
