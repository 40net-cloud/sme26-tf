###############################################################################
# Challenge 3-  root module: app – network + web service
###############################################################################

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "app_url" {
  description = "Open this in a browser (allow ~2 min for the instance to become healthy)."
  value       = module.app.url
}

output "alb_name" {
  value = module.app.alb_name
}

output "alb_log_bucket" {
  value = module.app.log_bucket
}

output "instance_id" {
  value = module.app.instance_id
}

output "db_password_parameter" {
  value = module.app.db_password_parameter
}
###############################################################################