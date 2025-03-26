variable "approval_email" {
  description = "Enter the email address to which approval notification needs to be sent"
  type        = string
  default     = "jcarraag@emeal.nttdata.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$", var.approval_email))
    error_message = "Expects a valid email address"
  }
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

variable "code_pipeline_artifact" {
  description = "Nombre del bucket de artefactos de CodePipeline"
  type        = string
  default     = "CodePipelineArtifact"
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

variable "GitHubOAuthToken" {
  description = "Token de acceso al repositorio de GitHub"
  type        = string
}