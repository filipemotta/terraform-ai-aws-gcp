resource "aws_subnet" "private" {
  count             = length(var.vpc.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc.private_subnets[count.index].cidr_block
  availability_zone = var.vpc.private_subnets[count.index].availability_zone

  tags = {
    Name = var.vpc.private_subnets[count.index].name
  }
}
