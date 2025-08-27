variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "jcarraag-tfg"
}

variable "environment" {
  description = "Entorno"
  type        = string
  default     = "dev"
}

variable "cidr_block" {
  description = "CIDR Block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "eu-central-1"
}

variable "stage" {
  description = "Stage de la pipeline a la que pertenece el recurso"
  type        = string
  default     = "deployment"
}