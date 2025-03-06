variable "vm_size" {
  description = "Tipo de instancia"
  type        = string
  default     = "Standard_B1s"
}

variable "custom_data_path" {
  description = "Ruta al script que ejecuta la instancia al iniciarse"
  type        = string
  default     = "./user_script.sh"
}

variable "ssh_key_name" {
  description = "Nombre de la llave SSH para las instancias"
  type        = string
  default     = "s-5-key-tf"
}

variable "ssh_key_path" {
  description = "Ruta al archivo de la clave pública SSH"
  type        = string
  default     = "./s-5-key-tf.pub"
}

variable "az1_public_web" {
  description = "Subred pública dentro de la AZ1 para web"
  type        = string
}

variable "az2_public_web" {
  description = "Subred pública dentro de la AZ2 para web"
  type        = string
}

variable "az1_private_app" {
  description = "Subred privada dentro de la AZ1 para app"
  type        = string
}

variable "az2_private_app" {
  description = "Subred privada dentro de la AZ2 para app"
  type        = string
}

variable "sg_web" {
  description = "Security group de las instancias web"
  type        = string
}

variable "sg_app" {
  description = "Security group de las instancias app"
  type        = string
}

variable "sg_bastion" {
  description = "Security group del bastion"
  type        = string
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

variable "admin_username" {
  description = "Nombre de usuario administrador para las VMs"
  type        = string
  default     = "adminuser"
}

variable "admin_password" {
  description = "Contraseña del usuario administrador para las VMs"
  type        = string
  default     = "adminuser1234!"
}