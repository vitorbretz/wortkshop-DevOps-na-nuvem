# Input Variables for Remote Backend Stack
# ADR-002: Terraform Remote Backend

# General Configuration
variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "dvn-workshop"
  nullable    = false
}

variable "environment" {
  description = "Environment name (shared across all envs)"
  type        = string
  default     = "shared"
  nullable    = false
}

# AWS Account ID (will be fetched via data source)
variable "aws_account_id" {
  description = "AWS Account ID (optional, will be auto-detected)"
  type        = string
  default     = ""
}

# S3 Backend Configuration
variable "backend_bucket" {
  description = "S3 backend bucket configuration"
  type = object({
    force_destroy = optional(bool, false)

    versioning = object({
      enabled    = bool
      mfa_delete = optional(bool, false)
    })

    lifecycle_rules = object({
      enabled                            = bool
      noncurrent_version_expiration      = number
      noncurrent_version_transition_days = number
    })

    encryption = object({
      sse_algorithm = string # AES256 or aws:kms
      kms_key_id    = optional(string, null)
    })

    logging = object({
      enabled       = bool
      target_bucket = optional(string, null)
      target_prefix = optional(string, "terraform-state-logs/")
    })
  })

  default = {
    force_destroy = false

    versioning = {
      enabled    = true
      mfa_delete = false
    }

    lifecycle_rules = {
      enabled                            = true
      noncurrent_version_expiration      = 90
      noncurrent_version_transition_days = 30
    }

    encryption = {
      sse_algorithm = "AES256"
      kms_key_id    = null
    }

    logging = {
      enabled       = false
      target_bucket = null
      target_prefix = "terraform-state-logs/"
    }
  }
}

# Tagging
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
