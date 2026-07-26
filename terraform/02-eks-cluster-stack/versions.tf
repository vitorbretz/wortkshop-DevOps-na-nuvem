# Terraform and Provider Version Constraints

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend Configuration - ADR-002
  backend "s3" {
    bucket       = "dvn-workshop-910661159891-terraform-state"
    key          = "02-eks-cluster-stack/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
