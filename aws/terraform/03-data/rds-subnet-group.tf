resource "aws_db_subnet_group" "this" {
  name       = var.rds.subnet_group_name
  subnet_ids = local.private_subnet_ids

  tags = {
    Name = var.rds.subnet_group_name
  }
}
