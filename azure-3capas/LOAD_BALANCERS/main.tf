resource "azurerm_application_load_balancer" "alb" {
  name = "Application Load Balancer"
  location = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_lb" "nlb" {
  name = "Network Load Balancer"
  location = var.location
  resource_group_name = var.resource_group_name

  
}