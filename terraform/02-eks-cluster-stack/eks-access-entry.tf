# EKS Access Entry
# ADR-003: Access entries for cluster authentication

# Access entry for current user (admin)
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.cluster_name}-admin-access"
      Description = "Admin access for current IAM user"
      User        = data.aws_caller_identity.current.arn
    }
  )
}

# Associate admin policy to the access entry
resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [
    aws_eks_access_entry.admin
  ]
}
