variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC and subnet"
  default     = "192.168.0.0/16"
}

variable "subnet_cidrs" {
  type        = map(string)
  description = "Map of subnet names to their CIDRs"
}

variable "az" {
  type        = string
  description = "Name of availability zone to deploy to"
}