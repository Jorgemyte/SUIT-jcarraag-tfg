module "infrastructure" {
  source = "./INFRASTRUCTURE"

  project_name = var.project_name
  environment  = var.environment
}