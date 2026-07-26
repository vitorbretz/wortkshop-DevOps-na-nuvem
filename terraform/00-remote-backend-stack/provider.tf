# AWS Provider Configuration
# ADR-002: Remote Backend Stack

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = var.environment
      ADR         = "ADR-002"
      Purpose     = "TerraformBackend"
    }
  }
}
