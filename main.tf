module "vpc" {
  source = "./components/vpc"

  prefix   = var.prefix
}

module "alb" {
  source = "./components/alb"

  vpc_id = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  acm_certificate_main_arn = module.route53_acm.acm_certificate_main_arn
  prefix   = var.prefix
  domain   = var.domain
}

module "route53_acm" {
  source = "./components/route53_acm"

  lb_main_dns_name = module.alb.lb_main_dns_name
  lb_main_zone_id = module.alb.lb_main_zone_id
  domain   = var.domain
}

module "rds" {
  source = "./components/rds"

  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  prefix   = var.prefix
  db_name   = var.db_name
  db_user   = var.db_user
  db_password   = var.db_password
}

module "ecs" {
  source = "./components/ecs"

  vpc_id = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  lb_listener_rule_main_arn = module.alb.lb_listener_rule_main_arn
  lb_target_group_main_arn = module.alb.lb_target_group_main_arn
  rds_cluster_endpoint = module.rds.rds_cluster_endpoint
  prefix   = var.prefix
  db_user   = var.db_user
  db_password = var.db_password
  app_image_name = var.app_image_name
  app_image_tag = var.app_image_tag
  nginx_image_name = var.nginx_image_name
  nginx_image_tag = var.nginx_image_tag
  rails_master_key = var.rails_master_key
}

module "db_create_task_definition" {
  source = "./tasks/db_create"

  app_image_name = var.app_image_name
  app_image_tag = var.app_image_tag
  rds_cluster_endpoint = module.rds.rds_cluster_endpoint
  db_user   = var.db_user
  db_password = var.db_password
  rails_master_key = var.rails_master_key
  iam_role_ecs_task_execution_role_arn = module.ecs.iam_role_ecs_task_execution_role_arn
}

module "db_migrate_task_definition" {
  source = "./tasks/db_migrate"

  app_image_name = var.app_image_name
  app_image_tag = var.app_image_tag
  rds_cluster_endpoint = module.rds.rds_cluster_endpoint
  db_user   = var.db_user
  db_password = var.db_password
  rails_master_key = var.rails_master_key
  iam_role_ecs_task_execution_role_arn = module.ecs.iam_role_ecs_task_execution_role_arn
}
