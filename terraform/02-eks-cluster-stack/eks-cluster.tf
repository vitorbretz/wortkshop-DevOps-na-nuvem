# EKS Cluster
# ADR-003: Amazon EKS cluster resource

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.eks_cluster.version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = concat(
      data.aws_subnets.private.ids,
      data.aws_subnets.public.ids
    )

    endpoint_private_access = var.eks_cluster.endpoint_access.private
    endpoint_public_access  = var.eks_cluster.endpoint_access.public
    public_access_cidrs     = var.eks_cluster.endpoint_access.public_access_cidrs
  }

  enabled_cluster_log_types = var.eks_cluster.logging.enabled ? var.eks_cluster.logging.types : []

  access_config {
    authentication_mode = var.eks_cluster.authentication_mode
  }

  tags = merge(
    local.common_tags,
    var.additional_tags,
    {
      Name        = local.cluster_name
      Description = "Amazon EKS cluster for containerized workloads"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]
}
