# Output Values
# ADR-002: Remote Backend Configuration (S3 Native Locking Only)

# S3 Bucket Outputs
output "s3_bucket_id" {
  description = "The name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "s3_bucket_region" {
  description = "The AWS region of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.region
}

# Backend Configuration
output "backend_config" {
  description = "Backend configuration for other Terraform stacks"
  value = {
    bucket  = aws_s3_bucket.terraform_state.id
    region  = data.aws_region.current.name
    encrypt = true
  }
}

# Backend Configuration Example
output "backend_config_example" {
  description = "Example backend configuration for terraform block"
  value = format(
    "terraform {\n  backend \"s3\" {\n    bucket        = \"%s\"\n    key           = \"STACK_NAME/terraform.tfstate\"\n    region        = \"%s\"\n    use_lockfile  = true\n    encrypt       = true\n  }\n}",
    aws_s3_bucket.terraform_state.id,
    data.aws_region.current.name
  )
}

# Account Information
output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}
