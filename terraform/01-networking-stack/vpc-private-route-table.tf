# Private Route Table
# ADR-001: Route table for private subnets with route to NAT Gateway

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt"
      Type = "private"
    }
  )
}

# Route to NAT Gateway for private subnets (conditional on NAT Gateway creation)
resource "aws_route" "private_nat_gateway" {
  count = var.create_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
