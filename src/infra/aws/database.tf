# RDS PostgreSQL 17 with pgvector. Smallest possible setup: single-AZ, no backups, deleted without a snapshot.

resource "random_password" "db" {
  length  = 24
  special = false # avoids characters that would need escaping in the connection URL
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db"
  subnet_ids = data.aws_subnets.supported.ids
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project}-db"
  engine         = "postgres"
  engine_version = "17" # major version; AWS picks the latest minor version
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "tsn"
  username = "tsn"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = true # needed for psql from the laptop; the security group limits who can connect

  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}
