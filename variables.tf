variable "region" {}
variable "profile" {}
variable "domain" {}

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

variable "image_name" {
  type = string
}
