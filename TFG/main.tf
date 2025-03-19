module "infrastructure" {
  source = "./INFRASTRUCTURE"

  stack_name  = var.stack_name
  environment = var.environment
  

}