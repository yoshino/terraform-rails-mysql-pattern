variable "image_name" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "rds_cluster_endpoint" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
}

variable "rails_master_key" {
  type = string
}

variable "iam_role_ecs_task_execution_role_arn" {
  type = string
}
