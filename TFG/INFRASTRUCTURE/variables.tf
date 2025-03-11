variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno"
  type        = string
}

variable "owner" {
  description = "Nombre del propietario"
  type        = string
  default     = "jcarraag"
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

// -------------------- VARIABLES CÓDIGO TEMPORAL

variable "container_name" {
  description = "Enter the name of the container to be used"
  type        = string
  default     = "suit-container-image"
}

variable "modules_table" {
  description = "Enter the name of the Modules Table"
  type        = string
  default     = "ModulesTable"
}

variable "status_table" {
  description = "Enter the name of the Status Table"
  type        = string
  default     = "StatusTable"
}

variable "test_output_bucket" {
  description = "Enter the name of the Test Output Bucket"
  type        = string
  default     = "TestOutputBucket"
}

variable "code_pipeline_artifact" {
  description = "Enter the name of the CodePipeline Artifact"
  type        = string
  default     = "CodePipelineArtifact"
}

variable "test_app_domain" {
  description = "Enter the name of the Test App Domain"
  type        = string
  default     = "TestAppDomain"
}