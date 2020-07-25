data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # アカウントID
  account_id = data.aws_caller_identity.current.account_id

  region = data.aws_region.current.name
}

resource "aws_iam_role" "ecs_task_execution_role" {
	name = "ecs_task_execution_role"
	assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ecs-tasks.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-policy" {
	role = aws_iam_role.ecs_task_execution_role.name
	policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr-read-policy" {
	role = aws_iam_role.ecs_task_execution_role.name
	policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Task Definition
# https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html
data "template_file" "container_definitions" {
  template = file("${path.module}/container_definitions.json")

  vars = {
    account_id = local.account_id
    region     = local.region
    app_image_name   = var.app_image_name
    app_image_tag = var.app_image_tag
    nginx_image_name   = var.nginx_image_name
    nginx_image_tag = var.nginx_image_tag

    db_host = var.rds_cluster_endpoint
    db_user = var.db_user
    db_password = var.db_password

    rails_master_key = var.rails_master_key
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.app_image_name}"
  retention_in_days = "7"
}

resource "aws_ecs_task_definition" "main" {
	family = var.prefix

	requires_compatibilities = ["FARGATE"]

	cpu    = "256"
	memory = "512"

	network_mode = "awsvpc"

	execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = data.template_file.container_definitions.rendered

  volume {
    name      = "socket-data"
  }
  volume {
    name      = "public-data"
  }
}

# ECS Cluster
# https://www.terraform.io/docs/providers/aws/r/ecs_cluster.html
resource "aws_ecs_cluster" "main" {
	name = var.prefix
}

# SecurityGroup
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group" "ecs" {
	name        = "${var.prefix}-ecs"
	description = "${var.prefix} ecs"

	vpc_id      = var.vpc_id

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
		Name = "${var.prefix}-ecs"
	}
}

# SecurityGroup Rule
# https://www.terraform.io/docs/providers/aws/r/security_group.html
resource "aws_security_group_rule" "ecs" {
	security_group_id = aws_security_group.ecs.id

	type = "ingress"

	from_port = 80
	to_port   = 8080
	protocol  = "tcp"

	cidr_blocks = ["10.0.0.0/16"]
}

# ECS Service
# https://www.terraform.io/docs/providers/aws/r/ecs_service.html
resource "aws_ecs_service" "main" {
	name = var.prefix

	depends_on = [var.lb_listener_rule_main_arn]

	cluster = aws_ecs_cluster.main.name

	launch_type = "FARGATE"

	desired_count = "1"

	task_definition = aws_ecs_task_definition.main.arn

	network_configuration {
		subnets         = var.private_subnet_ids
		security_groups = [aws_security_group.ecs.id]
	}

	load_balancer {
			target_group_arn = var.lb_target_group_main_arn
			container_name   = "nginx"
			container_port   = "8080"
		}
}
