// --------------------------------------------------------------------------- VNET --------------------------------------------------------------------------------
resource "azurerm_virtual_network" "mi_vnet" {
  name                = "VNET_Team_5"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    Name = "VNET_Team_5"
  }
}

// --------------------------------------------------------------------------- SUBNETS ------------------------------------------------------------------------------

resource "azurerm_subnet" "AZ1_Public_Subnet_Web" {
  name                 = "AZ1_Public_Subnet_Web"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mi_vnet.name
  address_prefixes     = [var.subnets_address_prefix.az1_public_web_address_prefix]
}

resource "azurerm_subnet" "AZ2_Public_Subnet_Web" {
  name                 = "AZ2_Public_Subnet_Web"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mi_vnet.name
  address_prefixes     = [var.subnets_address_prefix.az2_public_web_address_prefix]
}

resource "azurerm_subnet" "AZ1_Private_Subnet_App" {
  name                 = "AZ1_Private_Subnet_App"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mi_vnet.name
  address_prefixes     = [var.subnets_address_prefix.az1_private_app_address_prefix]
}

resource "azurerm_subnet" "AZ2_Private_Subnet_App" {
  name                 = "AZ2_Private_Subnet_App"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mi_vnet.name
  address_prefixes     = [var.subnets_address_prefix.az2_private_app_address_prefix]
}

resource "azurerm_subnet" "AZ1_Private_Subnet_DataServer" {
  name                 = "AZ1_Private_Subnet_DataServer"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mi_vnet.name
  address_prefixes     = [var.subnets_address_prefix.az1_private_data_address_prefix]
}

resource "azurerm_subnet" "AZ2_Private_Subnet_DataServer" {
  name                 = "AZ2_Private_Subnet_DataServer"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.mi_vnet.name
  address_prefixes     = [var.subnets_address_prefix.az2_private_data_address_prefix]
}