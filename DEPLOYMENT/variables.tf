variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "jcarraag-tfg"
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

// -------------------- VARIABLES CÓDIGO TEMPORAL ECS

variable "status_table" {
  description = "Nombre de la tabla de estado de DynamoDB"
  type        = string
  default     = "StatusTable-${var.project_name}"
}

variable "test_output_bucket" {
  description = "Nombre del bucket de salida de pruebas"
  type        = string
  default     = "TestOutputBucket"
}

variable "code_pipeline_artifact" {
  description = "Nombre del bucket de artefactos de CodePipeline"
  type        = string
  default     = "CodePipelineArtifact"
}

// -------------------- VARIABLES CÓDIGO TEMPORAL LAMBDA



// -------------------- VARIABLES CÓDIGO TEMPORAL UPDATE MODULES

variable "modules_table_name" {
  description = "Nombre de la tabla de módulos (DynamoDB Table)"
  type        = string
  default     = "ModulesTable"
}

// -------------------- VARIABLES CÓDIGO TEMPORAL SERVERLESS FIREFOX

variable "container_name" {
  description = "El nombre de la imagen del contenedor"
  type        = string
  default     = "suit-container-image"
}

variable "test_app_domain" {
  description = "El dominio de la aplicación de prueba"
  type        = string
  default     = "TestAppDomain"
}
