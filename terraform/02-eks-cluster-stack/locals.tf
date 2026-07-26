# Local Values
# ADR-003: EKS Cluster Stack

locals {
  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    ADR         = "ADR-003"
    Stack       = "eks-cluster"
  }

  # Cluster name
  cluster_name = "${var.project_name}-${var.environment}-eks"

  # Node group name
  node_group_name = "${local.cluster_name}-node-group"

  # IAM role names
  cluster_role_name = "${local.cluster_name}-cluster-role"
  node_role_name    = "${local.cluster_name}-node-role"
}
