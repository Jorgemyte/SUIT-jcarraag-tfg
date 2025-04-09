variable "repository_name" {
  description = "Enter the name of the container to be used"
  type        = string
  default     = "WebAppSourceRepo"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "jcarraag-TFG"
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "eu-central-1"
}