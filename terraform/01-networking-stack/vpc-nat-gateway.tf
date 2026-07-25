# NAT Gateway and Elastic IP
# ADR-001: Single NAT Gateway in first public subnet (us-east-1a)
# Trade-off: Cost optimization vs High Availability
# Note: Single point of failure - consider 2 NAT Gateways for production

resource "aws_eip" "nat" {
  count = var.create_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat"
    }
  )

  depends_on = [aws_internet_gateway.this]
}
