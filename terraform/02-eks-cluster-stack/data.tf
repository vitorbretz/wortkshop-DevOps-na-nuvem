# Data Sources
# ADR-003: EKS Cluster Stack

# Get current AWS account and region information
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Get existing VPC from networking stack
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-${var.environment}-vpc"]
  }
}

# Get private subnets for node groups
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

# Get public subnets for cluster endpoint
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  filter {
    name   = "tag:Type"
    values = ["public"]
  }
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
