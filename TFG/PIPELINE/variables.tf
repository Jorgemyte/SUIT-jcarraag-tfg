variable "repository_name" {
  description = "Enter the name of the CodeCommit repository"
  type        = string
  default     = "serverless-ui-testing"
}

variable "approval_email" {
  description = "Enter the email address to which approval notification needs to be sent"
  type        = string
  default     = "no-reply@example.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+$", var.approval_email))
    error_message = "Expects a valid email address"
  }
}

variable "stack_id" {
  description = "El ID del stack de AWS"
  type        = string
}

variable "stack_name" {
  description = "Nombre del stack"
  type        = string
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "eu-central-1"
}