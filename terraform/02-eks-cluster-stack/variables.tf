# Input Variables
# ADR-003: EKS Cluster Stack

# General Configuration
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# EKS Cluster Configuration
variable "eks_cluster" {
  description = "EKS cluster configuration"
  type = object({
    version = string

    endpoint_access = object({
      private             = bool
      public              = bool
      public_access_cidrs = list(string)
    })

    logging = object({
      enabled = bool
      types   = list(string)
    })

    authentication_mode = string
  })

  validation {
    condition = contains(
      ["API", "API_AND_CONFIG_MAP", "CONFIG_MAP"],
      var.eks_cluster.authentication_mode
    )
    error_message = "Authentication mode must be one of: API, API_AND_CONFIG_MAP, CONFIG_MAP"
  }
}

# Node Group Configuration
variable "node_group" {
  description = "EKS managed node group configuration"
  type = object({
    instance_types = list(string)
    capacity_type  = string

    scaling = object({
      desired_size = number
      min_size     = number
      max_size     = number
    })

    disk_size = number
    ami_type  = string
  })

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_group.capacity_type)
    error_message = "Capacity type must be either ON_DEMAND or SPOT"
  }

  validation {
    condition     = var.node_group.scaling.min_size <= var.node_group.scaling.desired_size && var.node_group.scaling.desired_size <= var.node_group.scaling.max_size
    error_message = "Scaling configuration must satisfy: min_size <= desired_size <= max_size"
  }
}

# Add-ons Configuration
variable "eks_addons" {
  description = "EKS add-ons to install"
  type = map(object({
    enabled = bool
    version = string
  }))
}

# Additional Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
