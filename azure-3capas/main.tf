// --------------------------------------------------------------------------- RESOURCE GROUP ------------------------------------------------------------------------------

resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group_name
  location = var.location
}

// --------------------------------------------------------------------------- MODULES ------------------------------------------------------------------------------

module "network" {
  source = "./NETWORKS"

  depends_on = [ azurerm_resource_group.resource_group ]
}

module "virtual_machines" {
  source = "./VMs"

  az1_public_web  = module.network.az1_public_web
  az2_public_web  = module.network.az2_public_web
  az1_private_app = module.network.az1_private_app
  az2_private_app = module.network.az2_private_app
  sg_web          = module.security_groups.sg_web
  sg_app          = module.security_groups.sg_app
  sg_bastion      = module.security_groups.sg_bastion

  depends_on = [ module.network, module.security_groups, azurerm_resource_group.resource_group ]

}

module "security_groups" {
  source = "./SECURITY_GROUPS"

  depends_on = [ module.network, azurerm_resource_group.resource_group ]
}

/* resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "example" {
  name = "exampleIP"
  allocation_method = "Dynamic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

resource "azurerm_virtual_machine" "example" {
  name                  = "example-machine"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.example.id]
  vm_size               = "Standard_DS1_v2"
  
  delete_os_disk_on_termination = true

   storage_os_disk {
    name                        = "example-os-disk"
    caching                     = "ReadWrite"
    create_option               = "FromImage"
    managed_disk_type           = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "example-machine"
    admin_username = "adminuser"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
} */