# Output Values
# ADR-003: EKS Cluster Stack

# Cluster Information
output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "The platform version for the cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = aws_eks_cluster.main.status
}

# Cluster Security
output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

# IAM Roles
output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS node group"
  value       = aws_iam_role.node.arn
}

output "node_iam_role_name" {
  description = "IAM role name of the EKS node group"
  value       = aws_iam_role.node.name
}

# Node Group Information
output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.main.status
}

output "node_group_resources" {
  description = "Resources associated with the EKS node group"
  value       = aws_eks_node_group.main.resources
}

# OIDC Provider
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.main.identity[0].oidc[0].issuer, null)
}

# Add-ons Status
output "addons_status" {
  description = "Status of installed EKS add-ons"
  value = {
    vpc_cni            = try(aws_eks_addon.vpc_cni[0].id, "not_installed")
    coredns            = try(aws_eks_addon.coredns[0].id, "not_installed")
    kube_proxy         = try(aws_eks_addon.kube_proxy[0].id, "not_installed")
    pod_identity_agent = try(aws_eks_addon.pod_identity_agent[0].id, "not_installed")
  }
}

# Kubectl Configuration
output "kubectl_config" {
  description = "kubectl config command to configure local kubectl"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.main.name}"
}

# Access Entry
output "admin_access_entry" {
  description = "Admin access entry principal ARN"
  value       = aws_eks_access_entry.admin.principal_arn
}
