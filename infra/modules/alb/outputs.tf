output "alb_dns" {
  value = aws_lb.this.dns_name
}

output "weather_target_group_arn" {
  value = aws_lb_target_group.weather_eks.arn
}
