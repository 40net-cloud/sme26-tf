output "eip" {
    value = aws_eip.fgt
}

output "fgt" {
    value = aws_instance.fgt
}

output "public_ip" {
    value = aws_eip.fgt.public_ip
}

output "id" {
    value = aws_instance.fgt.id
}