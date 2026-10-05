###############################################################################
# Challenge 1- FortiGate in Azure
# 
#   terraform init
#   terraform plan -var "subscription_id=$(az account show --query id -o tsv)"
#   terraform apply -var "subscription_id=$(az account show --query id -o tsv)"
# or put it in variables.tf 
#
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

###############################################################################
# RESOURCE GROUP
###############################################################################

resource "azurerm_resource_group" "fgt" {
  name     = "${var.prefix}-rg"
  location = var.location
}

###############################################################################
# VNET
###############################################################################

resource "azurerm_virtual_network" "fgt" {
  name                = "${var.prefix}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.fgt.name

  address_space = ["10.0.0.0/16"]
}

###############################################################################
# EXTERNAL SUBNET
###############################################################################

resource "azurerm_subnet" "external" {
  name                 = "external"
  resource_group_name  = azurerm_resource_group.fgt.name
  virtual_network_name = azurerm_virtual_network.fgt.name
  address_prefixes     = ["10.0.1.0/24"]
}

###############################################################################
# INTERNAL SUBNET
###############################################################################

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.fgt.name
  virtual_network_name = azurerm_virtual_network.fgt.name
  address_prefixes     = ["10.0.2.0/24"]
}

###############################################################################
# NETWORK SECURITY GROUP
###############################################################################

resource "azurerm_network_security_group" "fgt" {
  name                = "${var.prefix}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.fgt.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

###############################################################################
# PUBLIC IP
###############################################################################

resource "azurerm_public_ip" "fgt" {
  name                = "${var.prefix}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.fgt.name

  allocation_method = "Static"
  sku               = "Standard"
}

###############################################################################
# EXTERNAL NIC
###############################################################################

resource "azurerm_network_interface" "external" {
  name                = "${var.prefix}-nic-ext"
  location            = var.location
  resource_group_name = azurerm_resource_group.fgt.name

  enable_ip_forwarding = true


  ip_configuration {
    name                          = "external"
    subnet_id                     = azurerm_subnet.external.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.fgt.id
  }
}

###############################################################################
# INTERNAL NIC
###############################################################################

resource "azurerm_network_interface" "internal" {
  name                = "${var.prefix}-nic-int"
  location            = var.location
  resource_group_name = azurerm_resource_group.fgt.name

  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

###############################################################################
# NSG ASSOCIATION - EXTERNAL
###############################################################################

resource "azurerm_network_interface_security_group_association" "external" {
  network_interface_id      = azurerm_network_interface.external.id
  network_security_group_id = azurerm_network_security_group.fgt.id
}

###############################################################################
# NSG ASSOCIATION - INTERNAL
###############################################################################

resource "azurerm_network_interface_security_group_association" "internal" {
  network_interface_id      = azurerm_network_interface.internal.id
  network_security_group_id = azurerm_network_security_group.fgt.id
}

###############################################################################
# FORTIGATE VM
###############################################################################

resource "azurerm_linux_virtual_machine" "fgt" {
  name                = "${var.prefix}-fgt"
  location            = var.location
  resource_group_name = azurerm_resource_group.fgt.name

  size = "Standard_D4s_v5"

  network_interface_ids = [
    azurerm_network_interface.external.id,
    azurerm_network_interface.internal.id
  ]

  admin_username                  = var.username
  admin_password                  = var.password
  disable_password_authentication = false

  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = "fortinet"
    offer     = var.fgt_image_offer
    sku       = var.fgt_image_sku
    version   = var.fgt_version
  }

  plan {
    publisher = "fortinet"
    product   = var.fgt_image_offer
    name      = var.fgt_image_sku
  }

  os_disk {
    name                 = "${var.prefix}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  depends_on = [
    azurerm_network_interface_security_group_association.external,
    azurerm_network_interface_security_group_association.internal
  ]

  tags = {
    Environment = "Terraform-Lab"
    Product     = "FortiGate"
  }
}

###############################################################################
# DATA DISK
###############################################################################

resource "azurerm_managed_disk" "fgt_data" {
  name                = "${var.prefix}-data-disk"
  location            = var.location
  resource_group_name = azurerm_resource_group.fgt.name

  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 30
}

###############################################################################
# DATA DISK ATTACHMENT
###############################################################################

resource "azurerm_virtual_machine_data_disk_attachment" "fgt_data" {

  managed_disk_id = azurerm_managed_disk.fgt_data.id

  virtual_machine_id = "/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.fgt.name}/providers/Microsoft.Compute/virtualMachines/${var.prefix}-fgt"

  lun     = 0
  caching = "ReadWrite"
}