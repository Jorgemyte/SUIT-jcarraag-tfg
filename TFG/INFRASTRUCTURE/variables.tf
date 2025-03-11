variable "project_name" {
  description = "Nombre del proyecto"
  type = string
}

variable "environment" {
  description = "Entorno"
  type = string
}

variable "cidr_block" {
  description = "CIDR Block de la VPC"
  type = string
  default = "10.0.0.0/16"
}