// --------------------------------------------------------------------------- INSTANCIAS VM -----------------------------------------------------------------------

// --------------------------------------------------------------------------- VM_AZ1_WEB

resource "azurerm_virtual_machine" "VM_AZ1_WEB" {
  name                  = "VM_AZ1_WEB"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nic_VM_AZ1_Web.id]
  vm_size               = var.vm_size

  availability_set_id = "1"
  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "osdisk_VM_AZ1_WEB"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_profile {
    computer_name  = "vm-az1-web"
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data    = file(var.custom_data_path)
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = file(var.ssh_key_path)
    }
  }

  tags = {
    Name = "VM_AZ1_WEB"
  }
}

// --------------------------------------------------------------------------- VM_AZ2_WEB

resource "azurerm_virtual_machine" "VM_AZ2_WEB" {
  name                  = "VM_AZ2_WEB"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nic_VM_AZ2_Web.id]
  vm_size               = var.vm_size

  availability_set_id = "2"
  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "osdisk_VM_AZ2_WEB"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_profile {
    computer_name  = "vm-az2-web"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = file(var.ssh_key_path)
    }
  }

  tags = {
    Name = "VM_AZ2_WEB"
  }
}

// --------------------------------------------------------------------------- VM_AZ1_APP

resource "azurerm_virtual_machine" "VM_AZ1_APP" {
  name                  = "VM_AZ1_APP"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nic_VM_AZ1_App.id]
  vm_size               = var.vm_size

  availability_set_id = "1"
  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "osdisk_VM_AZ1_APP"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_profile {
    computer_name  = "vm-az1-app"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = file(var.ssh_key_path)
    }
  }

  tags = {
    Name = "VM_AZ1_APP"
  }
}

// --------------------------------------------------------------------------- VM_AZ2_APP

resource "azurerm_virtual_machine" "VM_AZ2_APP" {
  name                  = "VM_AZ2_APP"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nic_VM_AZ2_App.id]
  vm_size               = var.vm_size

  availability_set_id = "2"
  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "osdisk_VM_AZ2_APP"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_profile {
    computer_name  = "vm-az2-app"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = file(var.ssh_key_path)
    }
  }

  tags = {
    Name = "VM_AZ2_APP"
  }
}

// --------------------------------------------------------------------------- BASTION --------------------------------------------------------------------

resource "azurerm_virtual_machine" "bastion_host" {
  name                  = "bastion-host"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nic_BASTION.id]
  vm_size               = var.vm_size

  availability_set_id = "1"
  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "osdisk_bastion_host"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_profile {
    computer_name  = "bastion-host"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = file(var.ssh_key_path)
    }
  }

  tags = {
    Name = "bastion_host"
  }
}

// --------------------------------------------------------------------------- SSM AGENT --------------------------------------------------------------------

/* resource "azurerm_role_assignment" "ssm_role_assignment" {
  principal_id   = azurerm_virtual_machine.VM_AZ1_WEB.identity[0].principal_id
  role_definition_name = "Virtual Machine Contributor"
  scope          = azurerm_resource_group.example.id
}

resource "azurerm_role_assignment" "ssm_role_assignment_app" {
  principal_id   = azurerm_virtual_machine.VM_AZ1_APP.identity[0].principal_id
  role_definition_name = "Virtual Machine Contributor"
  scope          = azurerm_resource_group.example.id
} */

// --------------------------------------------------------------------------- NETWORK INTERFACES --------------------------------------------------------------------

// --------------------------------------------------------------------------- VM_AZ1_WEB_NIC

resource "azurerm_public_ip" "public_IP_VM_AZ1_Web" {
  name                = "public_IP_VM_AZ1_Web"
  allocation_method   = "Dynamic"
  location            = var.location
  resource_group_name = var.resource_group_name
}
resource "azurerm_network_interface" "nic_VM_AZ1_Web" {
  name                = "VM_AZ1_WEB_NIC"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "IP_VM_AZ1_public_web"
    subnet_id                     = var.az1_public_web
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_IP_VM_AZ1_Web.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_association_VM_AZ1_Web" {
  network_interface_id      = azurerm_network_interface.nic_VM_AZ1_Web.id
  network_security_group_id = var.sg_web
}

// --------------------------------------------------------------------------- VM_AZ2_WEB_NIC

resource "azurerm_public_ip" "public_IP_VM_AZ2_Web" {
  name                = "public_IP_VM_AZ2_Web"
  allocation_method   = "Dynamic"
  location            = var.location
  resource_group_name = var.resource_group_name
}
resource "azurerm_network_interface" "nic_VM_AZ2_Web" {
  name                = "VM_AZ2_WEB_NIC"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "IP_VM_AZ2_public_web"
    subnet_id                     = var.az2_public_web
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_IP_VM_AZ2_Web.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_association_VM_AZ2_Web" {
  network_interface_id      = azurerm_network_interface.nic_VM_AZ2_Web.id
  network_security_group_id = var.sg_web
}

// --------------------------------------------------------------------------- VM_AZ1_APP_NIC

resource "azurerm_network_interface" "nic_VM_AZ1_App" {
  name                = "VM_AZ1_APP_NIC"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "IP_VM_AZ1_private_app"
    subnet_id                     = var.az1_private_app
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_association_VM_AZ1_App" {
  network_interface_id      = azurerm_network_interface.nic_VM_AZ1_App.id
  network_security_group_id = var.sg_app
}

// --------------------------------------------------------------------------- VM_AZ2_APP_NIC

resource "azurerm_network_interface" "nic_VM_AZ2_App" {
  name                = "VM_AZ2_APP_NIC"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "IP_VM_AZ2_private_app"
    subnet_id                     = var.az2_private_app
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_association_VM_AZ2_App" {
  network_interface_id      = azurerm_network_interface.nic_VM_AZ2_App.id
  network_security_group_id = var.sg_app
}

// --------------------------------------------------------------------------- BASTION_NIC

resource "azurerm_public_ip" "public_IP_BASTION" {
  name                = "public_IP_BASTION"
  allocation_method   = "Dynamic"
  location            = var.location
  resource_group_name = var.resource_group_name
}
resource "azurerm_network_interface" "nic_BASTION" {
  name                = "BASTION_NIC"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "IP_BASTION"
    subnet_id                     = var.az1_public_web
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_IP_BASTION.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_association_BASTION" {
  network_interface_id      = azurerm_network_interface.nic_BASTION.id
  network_security_group_id = var.sg_web
}