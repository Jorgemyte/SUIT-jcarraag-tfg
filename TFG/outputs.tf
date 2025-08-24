output "pipeline_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.ServerlessUITestPipeline.name}/view"
}

output "test_app_url" {
  value = "https://${aws_amplify_branch.TestAppBranch.branch_name}.${aws_amplify_app.TestApp.default_domain}"
}

output "status_page_url" {
  value = "https://${aws_amplify_branch.StatusPageBranch.branch_name}.${aws_amplify_app.StatusPage.default_domain}"
}