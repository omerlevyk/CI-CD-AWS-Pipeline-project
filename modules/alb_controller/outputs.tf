output "service_account_name" {
  value = kubernetes_service_account_v1.alb_controller.metadata[0].name
}

output "iam_role_arn" {
  value = aws_iam_role.alb_controller.arn
}
output "iam_role_name" {
  value = aws_iam_role.alb_controller.name
}

