output "eip" {
  value = "https://${module.fgt.public_ip}/"
}

output "password" {
  value = module.fgt.id
}