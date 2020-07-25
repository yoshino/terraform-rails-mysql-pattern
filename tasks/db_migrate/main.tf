data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region = data.aws_region.current.name
}

# Task Definition
# https://www.terraform.io/docs/providers/aws/r/ecs_task_definition.html
data "template_file" "container_definitions" {
  template = file("${path.module}/container_definitions.json")

  vars = {
    account_id = local.account_id
    region     = local.region
    image_name   = var.image_name
    image_tag = var.image_tag
    db_host = var.rds_cluster_endpoint
    db_user = var.db_user
    db_password = var.db_password
    rails_master_key = var.rails_master_key
  }
}

resource "aws_ecs_task_definition" "db_migrate" {
	family = "db_migrate"
	requires_compatibilities = ["FARGATE"]
	cpu    = "256"
	memory = "512"
	network_mode = "awsvpc"
	execution_role_arn = var.iam_role_ecs_task_execution_role_arn
  container_definitions = data.template_file.container_definitions.rendered
}
