variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC and subnet"
  default     = "192.168.0.0/16"
}

variable "subnet_cidrs" {
  type        = map(string)
  description = "Map of subnet names to their CIDRs"
}

variable "flex_config_id" {
  type        = number
  description = "Flex config ID for FortiGate"
}

variable "flex_serial" {
  type        = string
  description = "FortiFlex serial number for FortiGate"
}
