# Ingress on the PostgreSQL port from the VPC CIDR only; no egress rule is
# needed for RDS. Nothing here is reachable from the internet.

resource "aws_security_group" "this" {
  name        = var.rds.security_group_name
  description = "PostgreSQL from inside the VPC"
  vpc_id      = local.vpc_id

  tags = {
    Name = var.rds.security_group_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  security_group_id = aws_security_group.this.id
  description       = "PostgreSQL from the VPC CIDR"
  cidr_ipv4         = local.vpc_cidr_block
  ip_protocol       = "tcp"
  from_port         = var.rds.port
  to_port           = var.rds.port

  tags = {
    Name = "${var.rds.security_group_name}-ingress-postgres"
  }
}
