// ---------------------------- AMPLIFY ROLES -------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "AmplifyAccessRole" {
  name = "SUIT-${var.project_name}-Prod-AmplifyRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  path = "/"
}

resource "aws_iam_policy" "AmplifyAccessRolePolicy" {
  name = "SUIT-${var.project_name}-Prod-AmplifyRole-Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/amplify/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmplifyAccessRolePolicyAttachment" {
  role       = aws_iam_role.AmplifyAccessRole.name
  policy_arn = aws_iam_policy.AmplifyAccessRolePolicy.arn
}

// ---------------------------- AMPLIFY -------------------------------------------------------

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = "jcarraag_GitHubOAuthToken"
}
resource "aws_amplify_app" "ProdApp" {
  name        = "ProdAppWebsite"
  repository  = "https://github.com/${var.GitHubOwner}/${var.GitHubRepo}"
  oauth_token = jsondecode(data.aws_secretsmanager_secret_version.github_token.secret_string)["jcarraag_github_oauth_token"]
  build_spec = jsonencode({
    version = 1
    applications = [
      {
        frontend = {
          phases = {
            build = {
              commands = []
            }
          }
          artifacts = {
            baseDirectory = "/"
            files         = ["**/*"]
          }
          cache = {
            paths = []
          }
          appRoot = "website"
        }
      }
    ]
  })

  iam_service_role_arn = aws_iam_role.AmplifyAccessRole.arn

  custom_rule {
    source = "/<*>"
    target = "/index.html"
    status = "404-200"
  }

  tags = {
    Application = var.project_name
    Name        = "ProdAppWebsite"
  }
}

resource "aws_amplify_branch" "ProdAppBranch" {
  app_id          = aws_amplify_app.ProdApp.id
  branch_name       = "master"
  description       = "Master branch for App"
  enable_auto_build = true
  stage           = "PRODUCTION"

  tags = {
    Application = var.project_name
    Name        = "ProdAppBranch"
  }
}

// ---------------------------- LAMBDA EXECUTION ROLE -------------------------------------------------------

resource "aws_iam_role" "LambdaExecutionRole" {
  name = "SUIT-${var.project_name}-Prod-LambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  path = "/"
}

resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRoleAttachment" {
  role       = aws_iam_role.LambdaExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "LambdaExecutionRolePolicy" {
  name        = "SUIT-${var.project_name}-Prod-LambdaExecutionRole-Policy"
  description = "Policy for Lambda to start Amplify jobs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "amplify:StartJob"
        Resource = "arn:aws:amplify:${var.aws_region}:${data.aws_caller_identity.current.account_id}:apps/${aws_amplify_app.ProdApp.id}/branches/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "LambdaExecutionRolePolicyAttachment" {
  role       = aws_iam_role.LambdaExecutionRole.name
  policy_arn = aws_iam_policy.LambdaExecutionRolePolicy.arn
}

// ---------------------------- TRIGGER DEPLOYMENT LAMBDA FUNCTION -------------------------------------------------------

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_function_payload_amplify.py"
  output_path = "lambda_function_payload_amplify.zip"
}

resource "aws_lambda_function" "TriggerDeploymentLambda" {
  description   = "Lambda function that will start Amplify deployment"
  filename      = "lambda_function_payload_amplify.zip"
  function_name = "SUIT-${var.project_name}-Prod-DeployAmplifyApp"
  role          = aws_iam_role.LambdaExecutionRole.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  timeout       = 85

  source_code_hash = data.archive_file.lambda.output_base64sha256
  

  environment {
    variables = {
      APP_ID      = aws_amplify_app.ProdApp.id
      BRANCH_NAME = aws_amplify_branch.ProdAppBranch.branch_name
    }
  }
}

// ---------------------------- TRIGGER DEPLOYMENT -------------------------------------------------------

resource "null_resource" "TriggerDeployment" {
  provisioner "local-exec" {
    command = <<EOT
      aws lambda invoke \
        --function-name ${aws_lambda_function.TriggerDeploymentLambda.function_name} \
        --payload '{"RequestType": "Create", "ResourceProperties": {"appId": "${aws_amplify_app.ProdApp.id}", "branchName": "${aws_amplify_branch.ProdAppBranch.branch_name}"}}' \
        response.json
    EOT
  }

  triggers = {
    app_id      = aws_amplify_app.ProdApp.id
    branch_name = aws_amplify_branch.ProdAppBranch.branch_name
  }
}

// ---------------------------- SSM PARAMETER -------------------------------------------------------

resource "aws_ssm_parameter" "ProdAppDomainParameter" {
  name        = "ProdAppURL"
  type        = "String"
  value       = "https://master.${aws_amplify_app.ProdApp.default_domain}"
  description = "URL of production website"
}

