module "deployment" {
  source = "./DEPLOYMENT"

  project_name = var.project_name
  environment  = var.environment

}