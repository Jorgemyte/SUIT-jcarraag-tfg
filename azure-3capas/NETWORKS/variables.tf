variable "vnet_address_space" {
  description = "Bloque CIDR para la VNET"
  type        = string
  default     = "10.5.0.0/16"
}

variable "location" {
  description = "Ubicación de los recursos en Azure"
  type        = string
  default     = "West Europe"
}

variable "resource_group_name" {
  description = "Nombre del grupo de recursos"
  type        = string
  default     = "jcarraag-resource-group"
}

variable "subnets_address_prefix" {
  description = "Bloque CIDR para cada subnet"
  type = object({
    az1_public_web_address_prefix   = string
    az2_public_web_address_prefix   = string
    az1_private_app_address_prefix  = string
    az2_private_app_address_prefix  = string
    az1_private_data_address_prefix = string
    az2_private_data_address_prefix = string
  })
  default = {
    az1_public_web_address_prefix   = "10.5.11.0/24"
    az2_public_web_address_prefix   = "10.5.12.0/24"
    az1_private_app_address_prefix  = "10.5.21.0/24"
    az2_private_app_address_prefix  = "10.5.22.0/24"
    az1_private_data_address_prefix = "10.5.31.0/24"
    az2_private_data_address_prefix = "10.5.32.0/24"
  }
}