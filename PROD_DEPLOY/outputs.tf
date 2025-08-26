output "prod_website_url" {
  value = "https://${aws_amplify_app.ProdApp.branch_name}.${aws_amplify_app.ProdApp.default_domain}"
}