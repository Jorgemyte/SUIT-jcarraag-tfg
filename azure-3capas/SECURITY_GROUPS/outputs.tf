output "sg_web" {
  description = "ID del Security Group de la capa web"
  value       = azurerm_network_security_group.sg_web.id
}

output "sg_app" {
  description = "ID del Security Group de la capa app"
  value       = azurerm_network_security_group.sg_app.id
}

output "sg_bastion" {
  description = "ID del Security Group del bastion"
  value       = azurerm_network_security_group.sg_bastion.id
}