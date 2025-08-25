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

variable "approval_email" {
  description = "Enter the email address to which approval notification needs to be sent"
  type        = string
  default     = "jcarraag@emeal.nttdata.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$", var.approval_email))
    error_message = "Expects a valid email address"
  }
}

variable "GitHubOwner" {
  description = "Propietario del repositorio de GitHub"
  type        = string
  default     = "Jorgemyte"
}

variable "GitHubRepo" {
  description = "Nombre del repositorio de GitHub"
  type        = string
  default     = "SUIT-jcarraag-tfg"
}

variable "codeconnection_arn" {
  description = "ARN de la conexión CodeConnections con GitHub"
  type        = string
  default     = "arn:aws:codeconnections:eu-central-1:864981728359:connection/b75500fb-f74e-46f7-8096-cb223b4386b0"
}
