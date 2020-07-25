variable "region" {
  type = string
}

variable "profile" {
  type = string
}

terraform {
  required_version = "~> 0.12"
}

provider "aws" {
  version = "~> 2.0"
  region  = var.region
  profile = var.profile
}

provider "github" {
  version = "~> 2.8"
}

variable "prefix" {
    default = "sample-project"
}

variable "domain" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
}

variable "db_name" {
  type = string
}

variable "rails_master_key" {
  type = string
}

variable "app_image_name" {
  type = string
}

variable "app_image_tag" {
  type = string
}

variable "nginx_image_name" {
  type = string
}

variable "nginx_image_tag" {
  type = string
}
