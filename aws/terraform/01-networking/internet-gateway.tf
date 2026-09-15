resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.vpc.internet_gateway_name
  }
}
