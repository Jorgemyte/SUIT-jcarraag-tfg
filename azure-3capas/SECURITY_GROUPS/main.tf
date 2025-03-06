resource "azurerm_network_security_group" "sg_web" {
  name                = "sg_web"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "HTTP_Inbound_Web"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 80
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 100
    access                     = "Allow"
  }

  security_rule {
    name                       = "SSH_Inbound_Web"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 101
    access                     = "Allow"
  }

  security_rule {
    name                       = "Outbound_Everything_Web"
    direction                  = "Outbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 102
    access                     = "Allow"
  }
}

resource "azurerm_network_security_group" "sg_app" {
  name                = "sg_app"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "HTTP_Inbound_App"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 80
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 100
    access                     = "Allow"
  }

  security_rule {
    name                       = "SSH_Inbound_App"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 101
    access                     = "Allow"
  }

  security_rule {
    name                       = "Outbound_Everything_App"
    direction                  = "Outbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 102
    access                     = "Allow"
  }
}

resource "azurerm_network_security_group" "sg_bastion" {
  name                = "sg_bastion"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "HTTP_Inbound_Bastion"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 80
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 100
    access                     = "Allow"
  }

  security_rule {
    name                       = "SSH_Inbound_Bastion"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 101
    access                     = "Allow"
  }

  security_rule {
    name                       = "Outbound_Everything_Bastion"
    direction                  = "Outbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 102
    access                     = "Allow"
  }
}