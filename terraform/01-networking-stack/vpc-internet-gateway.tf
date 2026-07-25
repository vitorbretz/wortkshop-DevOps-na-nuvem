# Internet Gateway
# ADR-001: Single IGW attached to VPC for public subnet internet access

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.additional_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}
