# Private Subnets
# ADR-001: 2 private subnets distributed across 2 AZs
# CIDR: 10.0.0.128/26 (us-east-1a), 10.0.0.192/26 (us-east-1b)

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-${var.availability_zones[count.index]}"
      Type = "private"
      Tier = "private"
    }
  )
}
