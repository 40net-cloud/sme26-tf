terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az = data.aws_availability_zones.available.names[0]
}


module "net" {
  source       = "./modules/net"
  vpc_cidr     = var.vpc_cidr
  subnet_cidrs = var.subnet_cidrs
  az           = local.az
}

module "fgt" {
  source = "./modules/fgt"

  az            = local.az
  subnet_cidrs  = var.subnet_cidrs
  fgt_user_data = data.cloudinit_config.fgt.rendered
}

// add your bootstrap data here 
data "cloudinit_config" "fgt" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "config"
    content_type = "text/x-shellscript"
    content      = <<EOF
    EOF
  }

  part {
    filename     = "license"
    content_type = "text/plain"
    content      = "LICENSE-TOKEN:FLEX_TOKEN_PLACEHOLDER"
  }
}


