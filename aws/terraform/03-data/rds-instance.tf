resource "aws_db_instance" "this" {
  identifier        = var.rds.identifier
  engine            = var.rds.engine
  engine_version    = var.rds.engine_version
  instance_class    = var.rds.instance_class
  allocated_storage = var.rds.allocated_storage
  storage_type      = var.rds.storage_type
  storage_encrypted = true

  db_name                     = var.rds.db_name
  username                    = var.rds.username
  manage_master_user_password = true
  port                        = var.rds.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = var.rds.multi_az

  backup_retention_period = var.rds.backup_retention_period
  deletion_protection     = var.rds.deletion_protection
  skip_final_snapshot     = var.rds.skip_final_snapshot

  tags = {
    Name = var.rds.identifier
  }
}
