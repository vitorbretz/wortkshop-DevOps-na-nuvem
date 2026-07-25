# Input Variables for Networking Stack
# ADR-001: VPC Network Architecture

# General Configuration
variable "aws_region" {
  description = "AWS region for infrastructure deployment"
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
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC - as per ADR-001"
  type        = string
  default     = "10.0.0.0/24"
  nullable    = false

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid IPv4 CIDR block"
  }
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
  nullable    = false
}

# Subnet Configuration
variable "availability_zones" {
  description = "List of availability zones for subnet distribution"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  nullable    = false

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones required as per ADR-001"
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets - as per ADR-001"
  type        = list(string)
  default     = ["10.0.0.0/26", "10.0.0.64/26"]
  nullable    = false

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly 2 public subnet CIDRs required as per ADR-001"
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets - as per ADR-001"
  type        = list(string)
  default     = ["10.0.0.128/26", "10.0.0.192/26"]
  nullable    = false

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly 2 private subnet CIDRs required as per ADR-001"
  }
}

# NAT Gateway Configuration
variable "create_nat_gateway" {
  description = "Create NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
  nullable    = false
}

# Tagging
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
