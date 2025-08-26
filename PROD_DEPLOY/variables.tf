variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "jcarraag-tfg"
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "eu-central-1"
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