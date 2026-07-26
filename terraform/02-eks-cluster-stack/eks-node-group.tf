# EKS Managed Node Group
# ADR-003: Managed node group for EKS cluster

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = local.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = data.aws_subnets.private.ids

  capacity_type  = var.node_group.capacity_type
  instance_types = var.node_group.instance_types
  disk_size      = var.node_group.disk_size
  ami_type       = var.node_group.ami_type

  scaling_config {
    desired_size = var.node_group.scaling.desired_size
    min_size     = var.node_group.scaling.min_size
    max_size     = var.node_group.scaling.max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role        = "worker"
    environment = var.environment
  }

  tags = merge(
    local.common_tags,
    var.additional_tags,
    {
      Name        = local.node_group_name
      Description = "Managed node group for EKS cluster"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy
  ]

  lifecycle {
    create_before_destroy = true
  }
}
