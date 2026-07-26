# EKS Cluster IAM Role
# ADR-003: IAM role for EKS cluster control plane

resource "aws_iam_role" "cluster" {
  name = local.cluster_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(
    local.common_tags,
    {
      Name        = local.cluster_role_name
      Description = "IAM role for EKS cluster control plane"
    }
  )
}

# Attach AmazonEKSClusterPolicy
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
