locals {
	name = "${var.prefix}-rds-mysql"
}

resource "aws_security_group" "this" {
	name        = local.name
	description = local.name

	vpc_id = var.vpc_id

  egress {
	  from_port   = 0
	  to_port     = 0
	  protocol    = "-1"
	  cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
	  Name = local.name
  }
}

resource "aws_security_group_rule" "mysql" {
	security_group_id = aws_security_group.this.id

	type = "ingress"

	from_port   = 3306
	to_port     = 3306
	protocol    = "tcp"
	cidr_blocks = ["10.0.0.0/16"]
}

resource "aws_db_subnet_group" "this" {
	name        = local.name
	description = local.name
	subnet_ids  = var.private_subnet_ids
}

# RDS Cluster
# https://www.terraform.io/docs/providers/aws/r/rds_cluster.html
resource "aws_rds_cluster" "this" {
	cluster_identifier = local.name

	db_subnet_group_name   = aws_db_subnet_group.this.name
	vpc_security_group_ids = [aws_security_group.this.id]

	engine = "aurora-mysql"
	port   = "3306"

	database_name   = var.db_name
	master_username = var.db_user
	master_password = var.db_password

	skip_final_snapshot = true

	db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
}

# RDS Cluster Instance
# https://www.terraform.io/docs/providers/aws/r/rds_cluster_instance.html
resource "aws_rds_cluster_instance" "this" {
	identifier         = local.name
	cluster_identifier = aws_rds_cluster.this.id

	engine = "aurora-mysql"

	instance_class = "db.t3.small"
}

# RDS Cluster Parameter Group
# https://www.terraform.io/docs/providers/aws/r/rds_cluster_parameter_group.html
resource "aws_rds_cluster_parameter_group" "this" {
	name   = local.name
	family = "aurora-mysql5.7"

	parameter {
		name  = "time_zone"
		value = "Asia/Tokyo"
	}

	parameter {
		name  = "character_set_client"
		value = "utf8mb4"
	}

	parameter {
		name  = "character_set_connection"
		value = "utf8mb4"
	}

	parameter {
		name  = "character_set_database"
		value = "utf8mb4"
	}

	parameter {
		name  = "character_set_results"
		value = "utf8mb4"
	}

	parameter {
		name  = "character_set_server"
		value = "utf8mb4"
	}
}
