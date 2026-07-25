# Public Subnets
# ADR-001: 2 public subnets distributed across 2 AZs
# CIDR: 10.0.0.0/26 (us-east-1a), 10.0.0.64/26 (us-east-1b)

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
      Type = "public"
      Tier = "public"
    }
  )
}
