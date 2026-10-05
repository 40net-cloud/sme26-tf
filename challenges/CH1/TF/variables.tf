###############################################################################
# Challenge 1- FortiGate in Azure
###############################################################################

variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "prefix" {
  type    = string
  default = "tf-fgt"
}

variable "username" {
  type    = string
  default = "azureadmin"
}

variable "password" {
  type      = string
  sensitive = true
}

# FortiGate Marketplace image.
# Adjust these values to the image/SKU available in your Azure subscription.
variable "fgt_image_offer" {
  type    = string
  default = "fortinet_fortigate-vm"
}

variable "fgt_image_sku" {
  type    = string
  default = "fortinet_fg-vm_byol_76"
}

variable "fgt_version" {
  type    = string
  default = "latest"
}
###############################################################################