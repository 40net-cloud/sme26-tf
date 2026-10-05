
###############################################################################
# Challenge 2- FortiGate in AWS 
###############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_ami" "fgt" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["FortiGate-VM*(7.4*"]
  }

  filter {
    name   = "product-code"
    values = ["2wqkpek696qhdeo7lbbjncqli"] # PAYG, Intel
  }
}

resource "aws_vpc" "lab" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "fgt-lab" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
}

resource "aws_subnet" "lab" {
  for_each = var.interfaces

  vpc_id            = aws_vpc.lab.id
  cidr_block        = each.value.cidr
  availability_zone = var.az
  tags              = { Name = "fgt-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.lab["port1"].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "fgt" {
  name   = "fgt-lab"
  vpc_id = aws_vpc.lab.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_network_interface" "fgt" {
  for_each = var.interfaces

  subnet_id         = aws_subnet.lab[each.key].id
  security_groups   = [aws_security_group.fgt.id]
  source_dest_check = false 
  tags              = { Name = "fgt-${each.key}" }
}

resource "aws_eip" "fgt" {
  domain            = "vpc"
  network_interface = aws_network_interface.fgt["port1"].id
  depends_on        = [aws_internet_gateway.lab]
}

resource "aws_instance" "fgt" {
  ami           = data.aws_ami.fgt.id
  instance_type = "c6i.large"

  # Bootstrap: set the admin password on first boot
  user_data = <<-EOT
    config system admin
      edit admin
        set password ${var.fgt_password}
      next
    end
  EOT

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.fgt["port1"].id
  }

  tags = { Name = "fgt" }
}

# Attach the non-primary NICs after launch
resource "aws_network_interface_attachment" "fgt" {
  for_each = {
    for k, v in var.interfaces :
    aws_network_interface.fgt[k].id => v if v.index > 0
  }

  instance_id          = aws_instance.fgt.id
  network_interface_id = each.key
  device_index         = each.value.index
}

# One SSM SecureString per extra admin
resource "aws_ssm_parameter" "fgt_admin" {
  for_each = var.fgt_admins

  name  = "/fgt/admins/${each.key}"
  type  = "SecureString"
  value = each.value
}

output "gui_url" {
  value = "https://${aws_eip.fgt.public_ip}"
}

output "login" {
  description = "Credentials for the FortiGate GUI"
  value       = "admin / ${var.fgt_password}"
  sensitive   = true # <-- the fix
}
