# One zonal NAT gateway in the first public subnet. A NAT per AZ is the
# production shape; a single NAT is the deliberate POC trade-off (cost).

resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name = "eip-${var.vpc.nat_gateway_name}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = var.vpc.nat_gateway_name
  }

  depends_on = [aws_internet_gateway.this]
}
