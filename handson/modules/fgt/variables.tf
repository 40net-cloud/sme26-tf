variable "subnet_cidrs" {
  type        = map(string)
  description = "Map of subnet names to their CIDRs"
}

variable "az" {
  type        = string
  description = "Name of availability zone to deploy to"
}

variable "fgt_user_data" {
  type        = string
  description = "Inline or MIME-multipart user data block for FortiGate"
}