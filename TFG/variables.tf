variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "jcarraag-TFG"
}

variable "environment" {
  description = "Entorno"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
}