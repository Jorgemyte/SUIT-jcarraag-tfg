// --------------------------------------------------------------------------- ALB SG -----------------------------------------------------------------------

resource "azurerm_network_security_group" "sg_alb" {
  name                = "sg_alb"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "HTTP_Inbound_ALB"
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
    name                       = "SSH_Inbound_ALB"
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
    name                       = "Outbound_Everything_ALB"
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

// --------------------------------------------------------------------------- WEB SG -----------------------------------------------------------------------

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
    source_application_security_group_ids = [ azurerm_network_security_group.sg_alb.id ]
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
    source_application_security_group_ids = [ azurerm_network_security_group.sg_alb.id ]
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

// --------------------------------------------------------------------------- NLB SG -----------------------------------------------------------------------

resource "azurerm_network_security_group" "sg_nlb" {
  name                = "sg_nlb"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "HTTP_Inbound_NLB"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 80
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 100
    access                     = "Allow"
    source_application_security_group_ids = [ azurerm_network_security_group.sg_web.id ]
  }

  security_rule {
    name                       = "SSH_Inbound_NLB"
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    priority                   = 101
    access                     = "Allow"
    source_application_security_group_ids = [ azurerm_network_security_group.sg_web.id ]
  }

  security_rule {
    name                       = "Outbound_Everything_NLB"
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

// --------------------------------------------------------------------------- APP SG -----------------------------------------------------------------------

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
    source_application_security_group_ids = [ azurerm_network_security_group.sg_nlb.id ]
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
    source_application_security_group_ids = [ azurerm_network_security_group.sg_nlb.id ]
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

// --------------------------------------------------------------------------- BASTION SG -----------------------------------------------------------------------

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