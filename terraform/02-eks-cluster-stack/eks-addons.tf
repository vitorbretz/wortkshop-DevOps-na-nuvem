# EKS Add-ons
# ADR-003: Essential EKS add-ons for cluster functionality

# VPC CNI Add-on
resource "aws_eks_addon" "vpc_cni" {
  count = var.eks_addons["vpc-cni"].enabled ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = var.eks_addons["vpc-cni"].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.cluster_name}-vpc-cni"
      Description = "VPC CNI networking plugin"
    }
  )
}

# CoreDNS Add-on
resource "aws_eks_addon" "coredns" {
  count = var.eks_addons["coredns"].enabled ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = var.eks_addons["coredns"].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.cluster_name}-coredns"
      Description = "CoreDNS for cluster DNS resolution"
    }
  )

  depends_on = [
    aws_eks_node_group.main
  ]
}

# kube-proxy Add-on
resource "aws_eks_addon" "kube_proxy" {
  count = var.eks_addons["kube-proxy"].enabled ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = var.eks_addons["kube-proxy"].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.cluster_name}-kube-proxy"
      Description = "Kube-proxy for network proxy"
    }
  )
}

# EKS Pod Identity Agent Add-on
resource "aws_eks_addon" "pod_identity_agent" {
  count = var.eks_addons["eks-pod-identity-agent"].enabled ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = var.eks_addons["eks-pod-identity-agent"].version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.cluster_name}-pod-identity-agent"
      Description = "EKS Pod Identity Agent for IAM roles for pods"
    }
  )
}
