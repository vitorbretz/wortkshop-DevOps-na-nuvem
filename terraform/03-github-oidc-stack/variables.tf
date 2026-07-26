variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "dvn-workshop"
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs"
  type        = list(string)
  default     = []
}
