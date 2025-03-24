// ---------------------------- APPROVAL TOPIC -------------------------------------------------------

resource "aws_sns_topic" "approval_topic" {
  name              = "${var.project_name}-approval-topic"
  kms_master_key_id = "alias/aws/sns"
  display_name      = "SUIT-Approval-Notification"

  /* subscription {
    endpoint = var.approval_email
    protocol = "email"
  } */

  tags = {
    Name        = "${var.project_name}-approval-topic"
  }
}

// ---------------------------- TEST OUTPUT BUCKET (S3 BUCKET) -------------------------------------------------------


data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "test_output_bucket" {
  bucket = "${var.project_name}-test-output-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {

  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_acl" "test_output_bucket_acl" {
  bucket = aws_s3_bucket.test_output_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "test_output_bucket_versioning" {
  bucket = aws_s3_bucket.test_output_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "test_output_bucket_encryption" {
  bucket = aws_s3_bucket.test_output_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

// ---------------------------- CODE PIPELINE ARTIFACT (S3 BUCKET) -------------------------------------------------------

resource "aws_s3_bucket" "codepipeline_artifact" {
  bucket = "${var.project_name}-codepipeline-artifact-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {

  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_acl" "codepipeline_artifact_acl" {
  bucket = aws_s3_bucket.codepipeline_artifact.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "codepipeline_artifact_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifact.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_artifact_encryption" {
  bucket = aws_s3_bucket.codepipeline_artifact.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

// ---------------------------- ECR REPOSITORY -------------------------------------------------------

resource "aws_ecr_repository" "suit_repo" {
  name = "suit-${var.project_name}-repo"

  image_tag_mutability = "MUTABLE"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository_policy" "suit_repo_policy" {
  repository = aws_ecr_repository.suit_repo.name

  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Sid    = "LambdaECRImageRetrievalPolicy"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:DeleteRepositoryPolicy",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy"
        ]
      }
    ]
  })
}

// ---------------------------- MODULES TABLE (DynamoDB Table) -------------------------------------------------------

resource "aws_dynamodb_table" "modules_table" {
  name         = "ModulesTable-${var.project_name}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "ModId"
    type = "S"
  }

  hash_key = "ModId"

  tags = {
    Name        = "ModulesTable-${var.project_name}"
  }
}

// ---------------------------- PARAMETERS -------------------------------------------------------

resource "aws_ssm_parameter" "modules_table_parameter" {
  name        = "ModulesTable"
  type        = "String"
  value       = aws_dynamodb_table.modules_table.name
  description = "SSM Parameter for Modules Table"
}

resource "aws_ssm_parameter" "test_output_bucket_parameter" {
  name        = "TestOutputBucket"
  type        = "String"
  value       = aws_s3_bucket.test_output_bucket.bucket
  description = "SSM Parameter for Test Output Bucket"
}

resource "aws_ssm_parameter" "codepipeline_artifact_parameter" {
  name        = "CodePipelineArtifact"
  type        = "String"
  value       = aws_s3_bucket.codepipeline_artifact.bucket
  description = "SSM Parameter for CodePipeline Artifact Bucket"
}

resource "aws_ssm_parameter" "source_repo_parameter" {
  name        = "WebAppSourceRepo"
  type        = "String"
  value       = var.repository_name
  description = "SSM Parameter for Source Repository"
}

// ---------------------------- STATUS TABLE (DynamoDB Table) -------------------------------------------------------

resource "aws_dynamodb_table" "status_table" {
  name         = "StatusTable-${var.project_name}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "testrunid"
    type = "S"
  }

  attribute {
    name = "testcaseid"
    type = "S"
  }

  hash_key  = "testrunid"
  range_key = "testcaseid"

  tags = {
    Name        = "StatusTable-${var.project_name}"
  }
}

resource "aws_ssm_parameter" "status_table_parameter" {
  name        = "StatusTable"
  type        = "String"
  value       = aws_dynamodb_table.status_table.name
  description = "SSM Parameter for Status Table"
}

// ---------------------------- COGNITO IDENTITY POOL & ROLES -------------------------------------------------------

resource "aws_cognito_identity_pool" "status_page_cognito_ip" {
  identity_pool_name               = "StatusPageCognitoIP_${var.project_name}"
  allow_unauthenticated_identities = true
}

resource "aws_iam_role" "status_page_unauth_role" {
  name = "StatusPageUnAuthRole-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.status_page_cognito_ip.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "unauthenticated"
          }
        }
      }
    ]
  })

  path = "/"
}

resource "aws_iam_role_policy" "status_page_unauth_policy" {
  name   = "StatusPageUnAuthRole-${var.project_name}-Policy"
  role   = aws_iam_role.status_page_unauth_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.status_table.arn
      }
    ]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "attach_cognito_unauth_role" {
  identity_pool_id = aws_cognito_identity_pool.status_page_cognito_ip.id

  roles = {
    "unauthenticated" = aws_iam_role.status_page_unauth_role.arn
  }
}

// ---------------------------- AMPLIFY & ROLES -------------------------------------------------------

resource "aws_iam_role" "AmplifyAccessRole" {
  name = "SUIT-${var.project_name}-AmplifyRole"

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

resource "aws_iam_policy" "AmplifyAccessPolicy" {
  name = "SUIT-${var.project_name}-AmplifyRole-Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPull"
        ]
        Resource = "arn:aws:codecommit:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.repository_name}"
      },
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

resource "aws_iam_role_policy_attachment" "AmplifyAccessPolicyAttachment" {
  role       = aws_iam_role.AmplifyAccessRole.name
  policy_arn = aws_iam_policy.AmplifyAccessPolicy.arn
}

resource "aws_amplify_app" "TestApp" {
  name       = "TestAppWebsite"
  repository = "https://git-codecommit.${var.aws.region}.amazonaws.com/v1/repos/${var.repository_name}"
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
            files = ["**/*"]
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
    Name        = "TestAppWebsite"
  }
}

resource "aws_amplify_branch" "TestAppBranch" {
  app_id          = aws_amplify_app.TestApp.id
  branch_name     = "master"
  description     = "Master branch for App"
  enable_auto_build = true
  stage           = "PRODUCTION"

  tags = {
    Name        = "TestAppBranch"
  }
}