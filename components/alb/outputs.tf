output "lb_main_dns_name" {
  value = aws_lb.main.dns_name
}

output "lb_main_zone_id" {
  value = aws_lb.main.zone_id
}

output "lb_listener_rule_main_arn" {
  value = aws_lb_listener_rule.main.arn
}

output "lb_target_group_main_arn" {
  value = aws_lb_target_group.main.arn
}
