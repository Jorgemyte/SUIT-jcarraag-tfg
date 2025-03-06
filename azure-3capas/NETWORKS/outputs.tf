output "vnet_id" {
  description = "ID de la VNET creada"
  value       = azurerm_virtual_network.mi_vnet.id
}

output "az1_public_web" {
  description = "ID de la subnet pública en AZ1 web"
  value       = azurerm_subnet.AZ1_Public_Subnet_Web.id
}

output "az2_public_web" {
  description = "ID de la subnet pública en AZ2 web"
  value       = azurerm_subnet.AZ2_Public_Subnet_Web.id
}

output "az1_private_app" {
  description = "ID de la subnet privada en AZ1 app"
  value       = azurerm_subnet.AZ1_Private_Subnet_App.id
}

output "az2_private_app" {
  description = "ID de la subnet privada en AZ2 app"
  value       = azurerm_subnet.AZ2_Private_Subnet_App.id
}

output "az1_private_data" {
  description = "ID de la subnet privada en AZ1 data"
  value       = azurerm_subnet.AZ1_Private_Subnet_DataServer.id
}

output "az2_private_data" {
  description = "ID de la subnet privada en AZ2 data"
  value       = azurerm_subnet.AZ2_Private_Subnet_DataServer.id
}
