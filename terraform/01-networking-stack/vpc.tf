# VPC Resource
# ADR-001: Main VPC with CIDR 10.0.0.0/24

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}
