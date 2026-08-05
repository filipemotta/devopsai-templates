output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_version_initial" {
  value = var.cluster_version
}

output "target_version" {
  value = var.target_version
}

output "karpenter_node_role" {
  description = "Referenced by the role field in manifests/ec2nodeclass.yaml"
  value       = module.karpenter.node_iam_role_name
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
