# AWS Provider Configuration
# Region: us-east-1 (as per ADR-001)

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = var.environment
      ADR         = "ADR-001"
    }
  }
}
