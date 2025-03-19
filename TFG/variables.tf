variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "eu-central-1"
}

variable "stack_name" {
  description = "Nombre del stack"
  type        = string
}

variable "environment" {
  description = "Entorno"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
}