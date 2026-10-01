output "vpc" {
  value = aws_vpc.one
}

output "subnet_ids" {
  value = { for sb in keys(var.subnet_cidrs) : sb => aws_subnet.all[sb].id }
}