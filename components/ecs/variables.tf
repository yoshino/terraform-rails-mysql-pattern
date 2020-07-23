variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list
}

variable "lb_listener_rule_main_arn" {
  type = string
}

variable "lb_target_group_main_arn" {
  type = string
}


variable "rds_cluster_endpoint" {
  type = string
}

variable "prefix" {
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

variable "image_name" {
  type = string
}

variable "image_tag" {
  type = string
}
