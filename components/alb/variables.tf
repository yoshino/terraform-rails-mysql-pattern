variable "prefix" {
  type = string
}

variable "domain" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list
}

variable "acm_certificate_main_arn" {
  type = string
}
