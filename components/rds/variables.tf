variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list
}

variable "prefix" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type = string
}
