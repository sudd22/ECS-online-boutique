resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags = {
    Name = "${var.environment}-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier                  = "${var.environment}-postgres-db"
  engine                      = "postgres"
  engine_version              = var.engine_version
  db_name                     = var.db_name
  instance_class              = var.instance_class
  allocated_storage           = var.allocated_storage
  username                    = var.db_username
  skip_final_snapshot         = true
  multi_az                    = var.multi_az
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [var.rds_sg_id]
  manage_master_user_password = true
  tags = {
    Name = "${var.environment}-postgres-db"
  }
}
