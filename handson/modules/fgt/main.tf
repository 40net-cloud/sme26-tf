terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


locals {
  subnets = ["pub", "prv"]
}

//
// Ports, EIP and security groups
//
resource "aws_network_interface" "fgt_ports" {
  for_each = toset(local.subnets)

  description       = "fgt-port${index(local.subnets, each.key) + 1}"
  subnet_id         = var.subnet_ids[each.key]
  source_dest_check = false
}

resource "aws_eip" "fgt" {
  network_interface = aws_network_interface.fgt_ports[local.subnets[0]].id
}

resource "aws_network_interface_sg_attachment" "fgt_posrt_sg" {
  for_each = toset(local.subnets)

  security_group_id    = aws_security_group.allow_all.id
  network_interface_id = aws_network_interface.fgt_ports[each.key].id
}


//
// FortiGate itself, secondary NIC, image
//
resource "aws_instance" "fgt" {
  ami               = data.aws_ami.fgt_latest.id
  instance_type     = "c5.large"
  availability_zone = var.az

  primary_network_interface {
    network_interface_id = aws_network_interface.fgt_ports[local.subnets[0]].id
  }

  user_data = var.fgt_user_data

  lifecycle {
    ignore_changes = [source_dest_check]
  }
}

resource "aws_network_interface_attachment" "fgt_ports" {
  count = length(local.subnets) - 1 //all subnets -1 (because port1 is alreadu attached as primary)

  instance_id          = aws_instance.fgt.id
  network_interface_id = aws_network_interface.fgt_ports[local.subnets[count.index + 1]].id
  device_index         = count.index + 1
}

data "aws_ami" "fgt_latest" {
  owners = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["FortiGate-VM64-AWS *"]
  }
  most_recent = true
}


//
// Simple open security group
//
resource "aws_security_group" "allow_all" {
  name        = "Allow All"
  description = "Allow all traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Public Allow"
  }
}
