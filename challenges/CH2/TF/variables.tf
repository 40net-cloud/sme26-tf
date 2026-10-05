###############################################################################
# Challenge 2-FortiGate in AWS
###############################################################################

variable "region" {
  type    = string
  default = "eu-west-3"
}

variable "az" {
  type    = string
  default = "eu-west-3a"
}

variable "admin_cidr" {
  description = "add your public IP, e.g. 203.0.113.10/32"
  type        = string
}

variable "fgt_password" {
  description = "FortiGate admin password"
  type        = string
  sensitive   = true
}

# Extra admin accounts, stored in SSM Parameter Store for the ops team.
# Pass it in, never commit it:
#   export TF_VAR_fgt_admins='{netops="...",security="..."}'
variable "fgt_admins" {
  description = "Extra FortiGate admins: username => password"
  type        = map(string)
  sensitive   = true
}

variable "interfaces" {
  type = map(object({
    index = number
    cidr  = string
  }))
  default = {
    port1 = { index = 0, cidr = "10.0.1.0/24" } # WAN + management
    port2 = { index = 1, cidr = "10.0.2.0/24" } # LAN
  }
}
###############################################################################