output "url" {
  value = "http://${aws_lb.app.dns_name}"
}

output "alb_name" {
  value = aws_lb.app.name
}

output "target_group_name" {
  value = aws_lb_target_group.app.name
}

output "log_bucket" {
  value = aws_s3_bucket.alb_logs.bucket
}

output "instance_id" {
  value = aws_instance.app.id
}

output "db_password_parameter" {
  value = aws_ssm_parameter.db_password.name
}
