# S3 Bucket for Terraform State
# ADR-002: Remote Backend Storage

resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.bucket_name
  force_destroy = var.backend_bucket.force_destroy

  tags = merge(
    local.common_tags,
    {
      Name        = local.bucket_name
      Description = "Terraform remote state storage"
    }
  )
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status     = var.backend_bucket.versioning.enabled ? "Enabled" : "Suspended"
    mfa_delete = var.backend_bucket.versioning.mfa_delete ? "Enabled" : "Disabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.backend_bucket.encryption.sse_algorithm
      kms_master_key_id = var.backend_bucket.encryption.kms_key_id
    }
    bucket_key_enabled = true
  }
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  count = var.backend_bucket.lifecycle_rules.enabled ? 1 : 0

  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = var.backend_bucket.lifecycle_rules.noncurrent_version_transition_days
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.backend_bucket.lifecycle_rules.noncurrent_version_expiration
    }
  }
}

# Access logging (optional)
resource "aws_s3_bucket_logging" "terraform_state" {
  count = var.backend_bucket.logging.enabled ? 1 : 0

  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = var.backend_bucket.logging.target_bucket
  target_prefix = var.backend_bucket.logging.target_prefix
}
